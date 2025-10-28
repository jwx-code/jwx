#!/bin/bash

# --- Check required parameter ---
if [ -z "$1" ]; then
  echo "Usage: $0 <instanceName> [--delete] (dev_multipass_start.sh)"
  echo "  instanceName : required string parameter (dev_multipass_start.sh)"
  echo "exit 1 (dev_multipass_start.sh)"
  exit 1
else
    echo "$0 will start now (dev_multipass_start.sh)"
    multipass start "$0"
fi
