#!/bin/bash

# --- Check required parameter ---
if [ -z "$1" ]; then
  echo "Usage: $0 <instanceName> [--delete] (dev_multipass_delete_instance.sh)"
  echo "  instanceName : required string parameter (dev_multipass_delete_instance.sh)"
  echo "exit 1 (dev_multipass_delete_instance.sh)"
  exit 1
else
echo "multipass instance $1 will deleted now (dev_multipass_delete_instance.sh)"
    multipass delete "$1" --purge
fi
