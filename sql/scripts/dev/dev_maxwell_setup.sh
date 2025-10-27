#!/bin/bash
#set -euo pipefail

# ----------------- Konfiguration (ANPASSEN) -----------------
# Wenn du das Skript auf deinem lokalen Host ausführst und die Kommandos
# in eine Multipass-VM weiterleiten willst, setze INSTANCE auf den VM-Namen.
# Wenn du das Skript direkt in der VM ausführst, lasse INSTANCE leer.
INSTANCE=""                # z.B. "jwxsql" oder "" wenn lokal in VM ausführen
MYSQL_ROOT_PWD="${MYSQL_ROOT_PWD:-rootpassword}"   # oder exportiere MYSQL_ROOT_PWD vorher
MAXWELL_PWD="${MAXWELL_PWD:-maxwell-password}"
JWXLOG_WRITER_PWD="${JWXLOG_WRITER_PWD:-jwxlog-pwd}"
JWX_MAIN_DB="JWX"
JWX_LOG_DB="JWX_LOG"

# ----------------- Helper: Multipass prefix -----------------
if [ -n "$INSTANCE" ]; then
  MP="multipass exec $INSTANCE --"
else
  MP=""
fi

# Helper-Funktion: führe Kommando mit evtl. multipass prefix aus
run() {
  # usage: run sudo apt update
  if [ -n "$MP" ]; then
    # preserve quoting: use eval on a single string
    eval "$MP $*"
  else
    eval "$*"
  fi
}

echo "=== Start setup-maxwell-logdb ==="
echo "Instance prefix: ${MP:-<none>}"
echo "Target log DB: $JWX_LOG_DB"

# ----------------- 1) MySQL binlog config -----------------
echo "1) Erstelle MySQL binlog config (/etc/mysql/mysql.conf.d/99-maxwell.cnf)..."
run sudo bash -c 'cat > /etc/mysql/mysql.conf.d/99-maxwell.cnf <<EOF
[mysqld]
server-id               = 1
log_bin                 = mysql-bin
binlog_format           = ROW
expire_logs_days        = 7
max_binlog_size         = 100M
# optional: adjust bind-address if you need remote access
# bind-address          = 0.0.0.0
EOF'

# ----------------- 2) Restart MySQL -----------------
echo "2) Neustart von MySQL..."
run sudo systemctl restart mysql
run sudo systemctl is-active --quiet mysql && echo "MySQL läuft." || { echo "MySQL startet nicht korrekt!"; exit 1; }

# ----------------- 3) Create DB and users -----------------
echo "3) Erstelle Datenbanken und Benutzer in MySQL..."
# We assume root password auth. If root uses socket auth, replace -uroot -p... by 'sudo mysql -e ...' or adjust.
# If you use socket auth, set MYSQL_ROOT_PWD empty and we'll use sudo mysql
if [ -z "${MYSQL_ROOT_PWD}" ]; then
  # socket auth
  run sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${JWX_LOG_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'maxwell'@'%' IDENTIFIED BY '${MAXWELL_PWD}';
GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'maxwell'@'%';
CREATE USER IF NOT EXISTS 'jwx_log_writer'@'%' IDENTIFIED BY '${JWXLOG_WRITER_PWD}';
GRANT ALL PRIVILEGES ON \`${JWX_LOG_DB}\`.* TO 'jwx_log_writer'@'%';
FLUSH PRIVILEGES;
SQL
else
  run mysql -uroot -p"${MYSQL_ROOT_PWD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${JWX_LOG_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'maxwell'@'%' IDENTIFIED BY '${MAXWELL_PWD}';
GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'maxwell'@'%';
CREATE USER IF NOT EXISTS 'jwx_log_writer'@'%' IDENTIFIED BY '${JWXLOG_WRITER_PWD}';
GRANT ALL PRIVILEGES ON \`${JWX_LOG_DB}\`.* TO 'jwx_log_writer'@'%';
FLUSH PRIVILEGES;
SQL
fi

echo "DB und Benutzer erstellt (falls nicht vorhanden)."

# ----------------- 4) Install Docker (falls noch nicht installiert) -----------------
echo "4) Prüfe Docker-Installation..."
if run bash -lc 'command -v docker >/dev/null 2>&1'; then
  echo "Docker ist bereits installiert."
else
  echo "Docker wird installiert (apt repository, GPG key, docker-ce)..."

  # install prerequisites
  run sudo apt-get update
  run sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

  # add docker GPG key and repo
  run sudo mkdir -p /etc/apt/keyrings
  run bash -lc 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg'
  run bash -lc 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'

  # install docker packages
  run sudo apt-get update
  run sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # enable and start docker
  run sudo systemctl enable --now docker

  echo "Docker installiert und gestartet."
fi

# Optional: add current user to docker group (nur wenn lokal ausgeführt)
if [ -z "$MP" ]; then
  # determine current user inside VM (who runs script)
  current_user=$(whoami)
  echo "Füge $current_user zur docker-Gruppe hinzu (erfordert Neuanmeldung um Effekt zu haben)..."
  sudo usermod -aG docker "$current_user" || true
fi

# ----------------- 5) Install Python MySQL connector (pip) -----------------
echo "5) Installiere python3-pip und mysql-connector-python..."
run sudo apt-get update
run sudo apt-get install -y python3 python3-pip
# statt sudo pip global zu benutzen -> venv anlegen und Pakete dort installieren
run sudo mkdir -p /opt/jwx_log
run sudo chown "$(whoami)":"$(whoami)" /opt/jwx_log

run python3 -m venv /opt/jwx_log/venv
run /opt/jwx_log/venv/bin/python -m pip install --upgrade pip
run /opt/jwx_log/venv/bin/pip install mysql-connector-python

# ----------------- 6) Sanity checks -----------------
echo "6) Sanity-Checks:"
echo "- MySQL master status:"
if [ -z "${MYSQL_ROOT_PWD}" ]; then
  run sudo mysql -e "SHOW MASTER STATUS\G" || true
else
  run mysql -uroot -p"${MYSQL_ROOT_PWD}" -e "SHOW MASTER STATUS\G" || true
fi

echo "- Docker version:"
run docker --version || true

echo "- Liste der Datenbanken (kurz):"
if [ -z "${MYSQL_ROOT_PWD}" ]; then
  run sudo mysql -e "SHOW DATABASES LIKE '${JWX_LOG_DB}';"
else
  run mysql -uroot -p"${MYSQL_ROOT_PWD}" -e "SHOW DATABASES LIKE '${JWX_LOG_DB}';"
fi

# ----------------- 7) Hinweise für Maxwell (Start/Test) -----------------
cat <<'EOF'

=== Fertig: Nächste Schritte ===

1) Teste Maxwell lokal (stdout) mit Docker (ersetze PASSWORT durch $MAXWELL_PWD):
   docker run --rm --network host zendesk/maxwell \
     bin/maxwell --user=maxwell --password=MAXWELL_PWD --host=127.0.0.1 --producer=stdout

   - Wenn du Multipass + VM verwendest und das Docker im VM läuft, führe diesen Befehl IN DER VM aus
     (entweder via 'multipass exec <vm> -- docker run ...' oder nach SSH ins VM).

2) Produktions-Pipeline (empfohlen):
   - Starte Kafka & Zookeeper (Docker Compose) und konfiguriere Maxwell mit producer=kafka.
   - Starte Kafka Connect + JDBC Sink Connector → schreibe in JWX_LOG mit user jwx_log_writer.

3) Falls du willst, erstelle ich dir:
   A) ein Docker-Compose Beispiel für Zookeeper+Kafka+Maxwell+Connect (JDBC Sink),
   B) oder ein kurzes Beispiel für Maxwell -> stdout -> einfacher Python-Consumer.

Hinweis: Ersetze Passwörter in Variablen am Anfang oder exportiere sensible Werte via Environment-Variablen,
z. B. export MYSQL_ROOT_PWD='…' bevor du das Skript startest.

EOF

echo "=== setup-maxwell-logdb abgeschlossen ==="
