# Allow access to the environment from any location or restrict it to your public ip
# Example:
#   access_ip      = "<YOUR IP>/32"
access_ip        = "0.0.0.0/0"

# Linux Username (Do not change)
linux_username   = "ubuntu"

# Windows Username and Password
windows_username = "admin"
windows_password = "${AWSONE_WINDOWS_PASSWORD}"

# Create Linux instance(s)
create_linux     = true

# Create Windows instance(s)
create_windows   = true

# AWS Account ID
account_id       = "${AWS_ACCOUNT_ID}"

# AWS Region
aws_region       = "${AWS_REGION}"
