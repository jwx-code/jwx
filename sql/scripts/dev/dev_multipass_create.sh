#!/bin/bash

# --- Check required parameter ---
if [ -z "$1" ]; then
  echo "Usage: $0 <instanceName> [--sql] (dev_multipass_create.sh)"
  echo "  instanceName : required string parameter (dev_multipass_create.sh)"
  exit 1
else
echo "2"
echo $1
    VM_NAME="$1"
    VM_MEM="2G"
    VM_DISK="10G"
    VM_CPUS="2"
    VM_CLOUD_INIT=" "
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "$2"
    if [ "$2" == "--sql" ]; then
          VM_CLOUD_INIT=$SCRIPT_DIR"/sql.yaml"
    else
        echo "error - invalid server type (dev_multipass_create.sh)"
        exit 1;
    fi
    
echo "$VM_NAME"
    echo "multipass starts now  (dev_multipass_create.sh)"
    multipass launch 24.04 --name "$VM_NAME" --mem "$VM_MEM" --disk "$VM_DISK" --cpus "$VM_CPUS" --cloud-init "$VM_CLOUD_INIT"
fi
