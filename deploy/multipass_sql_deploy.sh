#!/bin/bash

# --- Check required parameter ---
if [ -z "$1" ]; then
  echo "Usage: $0 <instanceName> <filepath>"
  echo "  instanceName : required string parameter"
  echo "  filePath     : required string parameter"
  exit 1
fi

# --- Assign parameters ---
INSTANCE="$1"
SQL_FILE="$2"  # default value


REMOTE_PATH="/tmp/$(basename "$SQL_FILE")"

# Prüfen, ob Datei existiert
if [ ! -f "$SQL_FILE" ]; then
  echo "Fehler: SQL-Datei '$SQL_FILE' wurde nicht gefunden." >&2
  exit 1
fi

# Datei in die Multipass-Instanz kopieren
echo "Übertrage SQL-Datei nach Multipass-Instanz '$INSTANCE' ..."
multipass transfer "$SQL_FILE" "$INSTANCE:$REMOTE_PATH"

# Skript in MySQL ausführen (als root)
echo "Führe SQL in MySQL auf '$INSTANCE' aus ..."
multipass exec "$INSTANCE" -- bash -lc "sudo mysql < '$REMOTE_PATH'"

echo "✅ SQL-Skript erfolgreich ausgeführt."
