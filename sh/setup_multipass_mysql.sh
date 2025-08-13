#!/bin/bash
# Erstellt eine Multipass-VM und installiert MySQL + OpenSSH
# Minimal & robust, ohne User-/Passwort-Anpassungen

# ===== Konfiguration =====
VM_NAME="mysql-server"
VM_MEM="2G"
VM_DISK="10G"
VM_CPUS="2"

set -euo pipefail

# ===== Prüfen, ob Multipass vorhanden ist =====
if ! command -v multipass &>/dev/null; then
  echo "❌ Multipass ist nicht installiert. Bitte zuerst installieren, z. B.:"
  echo "   brew install --cask multipass"
  exit 1
fi

# ===== (Optional) bestehende VM löschen =====
# Auskommentieren, wenn du IMMER frisch aufsetzen willst.
# if multipass info "$VM_NAME" &>/dev/null; then
#   echo "Lösche bestehende VM $VM_NAME..."
#   multipass delete "$VM_NAME" --purge
# fi

# ===== VM erstellen (falls nicht vorhanden) und starten =====
if multipass info "$VM_NAME" &>/dev/null; then
  echo "VM $VM_NAME existiert bereits. Starte sie..."
  multipass start "$VM_NAME"
else
  echo "Erstelle VM $VM_NAME (Ubuntu 24.04)..."
  multipass launch 24.04 --name "$VM_NAME" --mem "$VM_MEM" --disk "$VM_DISK" --cpus "$VM_CPUS"
fi

# ===== Pakete installieren =====
echo "Installiere MySQL Server und OpenSSH Server in der VM..."
multipass exec "$VM_NAME" -- bash -lc "sudo apt-get update -y"
multipass exec "$VM_NAME" -- bash -lc "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server openssh-server"

# ===== Dienste aktivieren & starten =====
echo "Aktiviere und starte Dienste..."
multipass exec "$VM_NAME" -- bash -lc "sudo systemctl enable --now mysql"
multipass exec "$VM_NAME" -- bash -lc "sudo systemctl enable --now ssh"

# ===== Status prüfen =====
echo "Prüfe Dienst-Status..."
multipass exec "$VM_NAME" -- bash -lc "sudo systemctl is-active --quiet mysql && echo 'MySQL läuft.' || (echo 'MySQL läuft nicht!' >&2; exit 1)"
multipass exec "$VM_NAME" -- bash -lc "sudo systemctl is-active --quiet ssh && echo 'SSH läuft.' || (echo 'SSH läuft nicht!' >&2; exit 1)"

# ===== IP ermitteln =====
VM_IP=$(multipass info "$VM_NAME" | awk '/IPv4/{print $2}')

cat <<EOF

✅ Fertig!

VM Name:   $VM_NAME
VM IP:     $VM_IP
Pakete:    mysql-server, openssh-server

Nutzung:
- In die VM einloggen (Shell):
    multipass shell $VM_NAME

- MySQL in der VM öffnen (Standard-Root via auth_socket):
    sudo mysql

- SSH in die VM (falls direkter SSH-Zugang gewünscht):
    ssh ubuntu@$VM_IP
  (Erster Login erfolgt bei Multipass typischerweise via 'multipass shell'.)

Hinweis:
- Dieses Skript setzt KEINE Passwörter / Benutzer in MySQL.
  Für Adminzugriff in der VM einfach:
    sudo mysql
  Wenn du User/PW oder Remote-Zugriff brauchst, sag Bescheid—ich ergänze dir das gezielt.
EOF
