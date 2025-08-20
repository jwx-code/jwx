#
//  setup_multipass_web.sh
//  jwx
//
//  Created by Jonas wrede on 20.08.25.
//

# ===== Konfiguration =====
VM_NAME="jwxweb"
VM_MEM="1G"
VM_DISK="5G"
VM_CPUS="2"
VM_INIT="apache.yaml"


# ===== VM erstellen (falls nicht vorhanden) und starten =====
if multipass info "$VM_NAME" &>/dev/null; then
  echo "VM $VM_NAME existiert bereits. Starte sie..."
  multipass start "$VM_NAME"
else
  echo "Erstelle VM $VM_NAME (Ubuntu 24.04)..."
  multipass launch 24.04 --name "$VM_NAME" --mem "$VM_MEM" --disk "$VM_DISK" --cpus "$VM_CPUS" --cloud-init "$VM_INIT"
fi


# ===== IP ermitteln =====
VM_IP=$(multipass info "$VM_NAME" | awk '/IPv4/{print $2}')

cat <<EOF

✅ WEB Fertig!

VM Name:   $VM_NAME
VM IP:     $VM_IP

EOF
####
