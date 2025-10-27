sudo mkdir -p /var/lib/maxwell
sudo mkdir -p /etc/maxwell
sudo mkdir -p /usr/local/lib/maxwell

sudo tee /etc/maxwell/importer.env >/dev/null <<'EOF'
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_DB=JWX_LOG
MYSQL_USER=jwx
MYSQL_PASSWORD=lol800mt2
MAXWELL_JSON=/var/lib/maxwell/maxwell-events.json
STATE_FILE=/var/lib/maxwell/importer.state.json
EOF

sudo tee /usr/local/lib/maxwell/maxwell_import.py >/dev/null <<'PY'
#!/usr/bin/env python3
import json, os, sys, mysql.connector

ENV = {
    'MYSQL_HOST': os.getenv('MYSQL_HOST', '127.0.0.1'),
    'MYSQL_PORT': int(os.getenv('MYSQL_PORT', '3306')),
    'MYSQL_DB':   os.getenv('MYSQL_DB', 'JWX_LOG'),
    'MYSQL_USER': os.getenv('MYSQL_USER', 'jwx'),
    'MYSQL_PASSWORD': os.getenv('MYSQL_PASSWORD', ''),
    'MAXWELL_JSON': os.getenv('MAXWELL_JSON', '/var/lib/maxwell/maxwell-events.json'),
    'STATE_FILE': os.getenv('STATE_FILE', '/var/lib/maxwell/importer.state.json'),
}

def load_state(path):
    try:
        with open(path, 'r') as f: return json.load(f)
    except: return {'offset': 0}

def save_state(path, state):
    tmp = path + '.tmp'
    with open(tmp, 'w') as f: json.dump(state, f)
    os.replace(tmp, path)

def connect_db():
    return mysql.connector.connect(
        host=ENV['MYSQL_HOST'],
        port=ENV['MYSQL_PORT'],
        user=ENV['MYSQL_USER'],
        password=ENV['MYSQL_PASSWORD'],
        database=ENV['MYSQL_DB'],
        autocommit=False,
    )

def ensure_table(conn):
    cur = conn.cursor()
    cur.execute("""
CREATE TABLE IF NOT EXISTS cdc_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  event_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  db_name VARCHAR(64) NOT NULL,
  table_name VARCHAR(64),
  event_type ENUM('insert','update','delete','ddl','heartbeat') NOT NULL,
  primary_key_json JSON NULL,
  row_before JSON NULL,
  row_after JSON NULL,
  ddl_sql LONGTEXT NULL,
  server_id BIGINT UNSIGNED NULL,
  binlog_file VARCHAR(64) NULL,
  binlog_pos BIGINT UNSIGNED NULL
) ENGINE=InnoDB;
""")
    conn.commit(); cur.close()

def extract_position(ev):
    pos = ev.get('position') or {}
    return (
        pos.get('server_id'),
        pos.get('binlog_file') or (ev.get('binlog') or {}).get('file'),
        pos.get('binlog_position') or (ev.get('binlog') or {}).get('position'),
    )

def main():
    state = load_state(ENV['STATE_FILE']); offset = state.get('offset', 0)
    path = ENV['MAXWELL_JSON']
    if not os.path.exists(path): return 0
    fsize = os.path.getsize(path)
    if offset > fsize: offset = 0

    conn = connect_db(); ensure_table(conn); cur = conn.cursor()
    inserted = 0
    with open(path, 'r', encoding='utf-8') as f:
        f.seek(offset)
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                ev = json.loads(line)
            except: continue
            db  = ev.get('database')
            tbl = ev.get('table') or None
            typ = ev.get('type')
            pk  = ev.get('primary_key') or ev.get('pk') or {}
            old = ev.get('old')
            new = ev.get('data')
            ddl = ev.get('sql')
            server_id, binlog_file, binlog_pos = extract_position(ev)
            cur.execute("""
INSERT INTO cdc_events
  (db_name, table_name, event_type, primary_key_json, row_before, row_after, ddl_sql, server_id, binlog_file, binlog_pos)
VALUES
  (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
""", (
    db, tbl, typ,
    json.dumps(pk) if pk is not None else None,
    json.dumps(old) if old is not None else None,
    json.dumps(new) if new is not None else None,
    ddl, server_id, binlog_file, binlog_pos
))
            inserted += 1
        conn.commit(); new_offset = f.tell()
    cur.close(); conn.close()
    save_state(ENV['STATE_FILE'], {'offset': new_offset})
    print(f"Imported {inserted} events, new offset={new_offset}")
    return 0

if __name__ == '__main__':
    sys.exit(main())
PY
sudo chmod +x /usr/local/lib/maxwell/maxwell_import.py

sudo tee /etc/systemd/system/maxwell.service >/dev/null <<'EOF'
[Unit]
Description=Maxwell CDC (Docker)
Wants=network-online.target
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=3
# Container startet Maxwell und schreibt Events in /var/lib/maxwell/maxwell-events.json
ExecStart=/usr/bin/docker run --rm --name maxwell --network host --user root -v /var/lib/maxwell:/data zendesk/maxwell bin/maxwell --host=127.0.0.1 --user=maxwell --password=lol800mt2 --schema_database=maxwell --filter=include:JWX.* --output_primary_keys=true --output_ddl=true --producer=file --output_file=/data/maxwell-events.json --log_level=info
ExecStop=/usr/bin/docker stop maxwell

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now maxwell.service


sudo tee /etc/systemd/system/maxwell-import.service >/dev/null <<'UNIT'
[Unit]
Description=Import Maxwell JSON events into JWX_LOG.cdc_events
After=network-online.target maxwell.service

[Service]
Type=oneshot
EnvironmentFile=/etc/maxwell/importer.env
ExecStart=/usr/bin/python3 /usr/local/lib/maxwell/maxwell_import.py
User=root
Group=root
UNIT



sudo tee /etc/systemd/system/maxwell-import.timer >/dev/null <<'UNIT'
[Unit]
Description=Run Maxwell importer every minute

[Timer]
OnBootSec=30sec
OnUnitActiveSec=60sec
AccuracySec=10sec
Unit=maxwell-import.service
Persistent=true

[Install]
WantedBy=timers.target
UNIT


sudo systemctl daemon-reload
sudo systemctl start maxwell-import.service
sudo journalctl -u maxwell-import.service -n 50 --no-pager
sudo systemctl enable --now maxwell-import.timer
