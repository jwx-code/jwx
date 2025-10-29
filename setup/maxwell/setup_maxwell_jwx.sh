#!/bin/bash

# --- Check required parameter ---
if [ -z "$1" ]; then
  echo "Usage: $0 <instanceName>"
  echo "  instanceName : required string parameter"
  exit 1
fi

# --- Assign parameters ---
INSTANCE="$1"

echo "==== [1] Delete old maxwell.cnf ===="
multipass exec "$INSTANCE" -- sudo bash -lc "rm -f /etc/mysql/conf.d/maxwell.cnf"

echo "==== [2] Create maxwell.cnf with binlog/ROW ===="
multipass exec "$INSTANCE" -- sudo bash -lc "cat > /etc/mysql/conf.d/maxwell.cnf <<'EOF'
[mysqld]
server-id=1
log_bin=binlog
binlog_format=ROW
binlog_row_image=FULL
expire_logs_days=7
EOF
sudo systemctl restart mysql
sleep 2
sudo mysql -e \"SHOW VARIABLES LIKE 'binlog_format'; SHOW VARIABLES LIKE 'log_bin'; SHOW VARIABLES LIKE 'binlog_row_image';\" || true"

echo "==== [3] Create Maxwell DB/User ===="
multipass exec "$INSTANCE" -- sudo bash -lc "sudo mysql -e \"
CREATE DATABASE IF NOT EXISTS maxwell;
CREATE USER IF NOT EXISTS 'maxwell'@'127.0.0.1' IDENTIFIED WITH mysql_native_password BY 'secret_pass';
GRANT SELECT, REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'maxwell'@'127.0.0.1';
GRANT ALL PRIVILEGES ON maxwell.* TO 'maxwell'@'127.0.0.1';
FLUSH PRIVILEGES;\""

echo "==== [4] Install packages / Docker ===="
multipass exec "$INSTANCE" -- sudo bash -lc "sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release"
multipass exec "$INSTANCE" -- sudo bash -lc "curl -fsSL https://get.docker.com | sudo sh"
multipass exec "$INSTANCE" -- sudo bash -lc "sudo usermod -aG docker ubuntu || true"
multipass exec "$INSTANCE" -- sudo bash -lc "sudo apt install -y docker-compose-plugin || true"

echo "==== [5] Create Maxwell directory ===="
multipass exec "$INSTANCE" -- sudo mkdir -p /var/lib/maxwell
multipass exec "$INSTANCE" -- sudo chown 1000:1000 /var/lib/maxwell
multipass exec "$INSTANCE" -- ls -ld /var/lib/maxwell

echo "==== [6] Start Maxwell container on 127.0.0.1 ===="
multipass exec "$INSTANCE" -- sudo docker rm -f maxwell 2>/dev/null || true
multipass exec "$INSTANCE" -- sudo docker run -d \
  --name maxwell \
  --network host \
  -v /var/lib/maxwell:/maxwell \
  zendesk/maxwell:latest \
  bin/maxwell \
    --user=maxwell \
    --password=secret_pass \
    --host=127.0.0.1 \
    --producer=file \
    --output_file=/maxwell/events.json \
    --replica-server-id=555

sleep 5
multipass exec "$INSTANCE" -- sudo docker logs --tail 50 maxwell

echo "==== [7] Create test events ===="
multipass exec "$INSTANCE" -- bash -lc "mysql -uroot -p'ROOT_PASS' -e \"
CREATE DATABASE IF NOT EXISTS testdb;
USE testdb;
CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100));
INSERT INTO users (name) VALUES ('Alice'),('Bob');\""

echo "==== [8] Check Maxwell events.json ===="
multipass exec "$INSTANCE" -- sudo bash -lc "if [ -f /var/lib/maxwell/events.json ]; then tail -n 100 /var/lib/maxwell/events.json; else echo 'events.json not found'; fi"

echo "==== [9] List /var/lib/maxwell ===="
multipass exec "$INSTANCE" -- sudo ls -la /var/lib/maxwell

echo "==== Done ===="
