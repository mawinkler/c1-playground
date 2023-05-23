#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

cd $PGPATH/terraform-awsone
terraform init
terraform destroy -auto-approve

printf '\n%s\n' "###TASK-COMPLETED###"
