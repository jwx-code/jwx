#!/bin/bash

# --- Check required parameter ---
if [ -z "$1" ]; then
  echo "Usage: $0 <instanceName> [--delete]"
  echo "  instanceName : required string parameter"
  echo "  --delete     : optional boolean flag (default: false)"
  exit 1;
else
    # --- Assign parameters ---

    # Get the directory where THIS script lives
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _instanceName="$1"
    _delete=false  # default
    _new=true    # default

    # --- Check optional flag ---
    if [ "$2" == "--delete" ]; then
      _delete=true
    fi
    if multipass info "$_instanceName" &>/dev/null; then
        _new=false
    fi
    
    if $_delete; then
        if $_new; then
        echo "instance does not exists (dev_multipass.sh)"
            echo "exit 1 (dev_multipass.sh)"
            exit 1;
        else
        echo  "$SCRIPT_DIR"/dev_multipass_delete.sh
            #execute script: delete inctance
            "$SCRIPT_DIR"/dev_multipass_delete.sh "$_instanceName"
        fi
    else
        if $_new; then
            #execute script: install instance
            "$SCRIPT_DIR"/dev_multipass_create.sh "$_instanceName" --sql
        else
            #execute script: start inctance
            "$SCRIPT_DIR"/dev_multipass_start.sh  "$_instanceName"
        fi
    fi
fi



