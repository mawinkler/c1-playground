# AWS Region
aws_region = "${AWS_REGION}"

# Allow access to the environment from any location or restrict it to your public ip
# Example:
#   access_ip      = "<YOUR IP>/32"
access_ip = "${ACCESS_IP}"

# Linux Username (Do not change)
linux_username = "ubuntu"

# Windows Username
windows_username = "admin"

# Create Linux instance(s)
create_linux = ${CREATE_LINUX}

# Create Windows instance(s)
create_windows = ${CREATE_WINDOWS}

# Environment Name
environment = "${AWS_ENVIRONMENT}"
