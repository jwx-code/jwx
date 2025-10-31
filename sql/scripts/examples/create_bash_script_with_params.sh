#
//  create_script_with_params.sh
//  jwx
//
//  Created by Jonas wrede on 27.10.25.
//

#!/bin/bash

# --- Check required parameter ---
if [ -z "$1" ]; then
  echo "Usage: $0 <instanceName> [--delete]"
  echo "  instanceName : required string parameter"
  echo "  --delete     : optional boolean flag (default: false)"
  exit 1
fi

# --- Assign parameters ---
instanceName="$1"
delete=false  # default value

# --- Check optional flag ---
if [ "$2" == "--delete" ]; then
  delete=true
fi

# --- Print what we got ---
echo "Instance Name: $instanceName"
echo "Delete Flag: $delete"

# --- Example logic ---
if $delete; then
  echo "Deleting instance '$instanceName'..."
  # put your delete command here, e.g.:
  # aws ec2 terminate-instances --instance-ids "$instanceName"
else
  echo "Performing actions on instance '$instanceName'..."
  # put your normal logic here
fi


# Example Usage
# Missing required argument
./manage-instance.sh
# Output: Usage: ./manage-instance.sh <instanceName> [--delete]

# Required only
./manage-instance.sh my-server
# Output:
# Instance Name: my-server
# Delete Flag: false
# Performing actions on instance 'my-server'...

# With optional flag
./manage-instance.sh my-server --delete
# Output:
# Instance Name: my-server
# Delete Flag: true
# Deleting instance 'my-server'...
