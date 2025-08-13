#!/bin/bash
# ===== Konfiguration =====
VM_NAME="mysql-server"
VM_MEM="2G"
VM_DISK="10G"
VM_CPUS="2"
MYSQL_USER="jwx"
ROOT_PASSWORD="lol800"        # Root bleibt mit Passwort geschützt
MYSQL_PORT_LOCAL=3306

set -e

# ===== Multipass installieren (falls nötig) =====
if ! command -v multipass &> /dev/null; then
  echo "Multipass wird installiert..."
  brew install --cask multipass
fi

# ===== Alte VM löschen, falls vorhanden =====
if multipass info "$VM_NAME" &>/dev/null; then
  echo "Lösche bestehende VM $VM_NAME..."
  multipass delete "$VM_NAME" --purge
fi

# ===== Neue VM starten =====
echo "Starte VM $VM_NAME..."
multipass launch 24.04 --name "$VM_NAME" --mem "$VM_MEM" --disk "$VM_DISK" --cpus "$VM_CPUS"

# ===== Pakete installieren & MySQL starten =====
echo "Installiere MySQL Server..."
multipass exec "$VM_NAME" -- sudo apt-get update -y
multipass exec "$VM_NAME" -- sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server openssh-server net-tools

echo "Aktiviere und starte MySQL..."
multipass exec "$VM_NAME" -- sudo systemctl enable --now mysql

# Warten bis MySQL aktiv ist
echo "Warte bis MySQL bereit ist..."
multipass exec "$VM_NAME" -- bash -lc 'for i in {1..30}; do sudo systemctl is-active --quiet mysql && exit 0; sleep 1; done; echo "MySQL startete nicht rechtzeitig" >&2; exit 1'

# ===== MySQL konfigurieren (über Maintenance-Account) =====
RUN_SQL="sudo mysql --defaults-file=/etc/mysql/debian.cnf -e"

echo "Konfiguriere MySQL Benutzer (ohne Passwort) und Remote-Zugriff..."

# Root absichern (mit Passwort)
multipass exec "$VM_NAME" -- bash -lc "$RUN_SQL \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${ROOT_PASSWORD}'; FLUSH PRIVILEGES;\""

# jwx OHNE Passwort anlegen (lokal & remote)
multipass exec "$VM_NAME" -- bash -lc "$RUN_SQL \"CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '';\""
multipass exec "$VM_NAME" -- bash -lc "$RUN_SQL \"CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED WITH mysql_native_password BY '';\""

# Rechte vergeben
multipass exec "$VM_NAME" -- bash -lc "$RUN_SQL \"GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'localhost' WITH GRANT OPTION;\""
multipass exec "$VM_NAME" -- bash -lc "$RUN_SQL \"GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION;\""
multipass exec "$VM_NAME" -- bash -lc "$RUN_SQL \"FLUSH PRIVILEGES;\""

# MySQL Config für externen Zugriff anpassen
multipass exec "$VM_NAME" -- sudo sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
multipass exec "$VM_NAME" -- sudo systemctl restart mysql

# ===== SSH-Key & IP ermitteln =====
MP_SSH_KEY=$(multipass info "$VM_NAME" --format json | grep -o '"identityFile": *"[^"]*"' | sed 's/"identityFile": *"//;s/"//')
VM_IP=$(multipass info "$VM_NAME" | awk '/IPv4/{print $2}')

# ===== Lokalen Port-Tunnel neu aufsetzen =====
echo "Setze localhost-Porttunnel auf ${MYSQL_PORT_LOCAL} neu..."
# Falls bereits ein Tunnel auf 3306 läuft: beenden
if lsof -iTCP:${MYSQL_PORT_LOCAL} -sTCP:LISTEN >/dev/null 2>&1; then
  pkill -f "ssh .* -L ${MYSQL_PORT_LOCAL}:127.0.0.1:3306" || true
  sleep 0.5
fi

# Tunnel starten
ssh -f -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${MP_SSH_KEY}" -L ${MYSQL_PORT_LOCAL}:127.0.0.1:3306 ubuntu@"${VM_IP}" -N

# ===== Ergebnis anzeigen =====
cat <<EOF

✅ MySQL Server ist bereit!

VM Name:        $VM_NAME
VM IP:          $VM_IP
MySQL Benutzer: $MYSQL_USER  (OHNE Passwort)
Root Passwort:  $ROOT_PASSWORD

Von macOS aus verbinden (lokal getunnelt, OHNE Passwort):
  mysql -h 127.0.0.1 -P ${MYSQL_PORT_LOCAL} -u ${MYSQL_USER} --skip-password

In die VM einloggen:
  multipass shell $VM_NAME
  mysql -u ${MYSQL_USER}       # kein -p nötig
  sudo mysql -u root -p${ROOT_PASSWORD}

Hinweis:
- Falls 'mysql' auf deinem Mac fehlt:
    brew install mysql-client
    echo 'export PATH="/opt/homebrew/opt/mysql-client/bin:\$PATH"' >> ~/.zshrc && source ~/.zshrc
EOF
