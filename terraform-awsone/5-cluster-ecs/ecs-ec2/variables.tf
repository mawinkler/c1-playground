# #############################################################################
# Variables
# #############################################################################
variable "environment" {}

variable "vpc_id" {}

variable "account_id" {}

variable "aws_region" {}

variable "access_ip" {}

variable "private_subnet_ids" {}

variable "public_subnet_ids" {}

variable "private_security_group_id" {}

variable "private_subnet_cidr_blocks" {}

variable "create_fargate_profile" {
  default = false
}
