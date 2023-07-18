# #############################################################################
# Create VPC
# #############################################################################
resource "aws_vpc" "vpc" {
    cidr_block           = var.vpc_cidr
    enable_dns_support   = true
    enable_dns_hostnames = true
    # enable_classiclink = "false"
    instance_tenancy = "default"

    tags = {
        Name        = "${var.environment}-vpc"
        Environment = "${var.environment}"
    }
}
