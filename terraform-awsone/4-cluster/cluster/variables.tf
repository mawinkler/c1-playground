# #############################################################################
# Variables
# #############################################################################
variable "environment" {}

variable "vpc_id" {}

variable "account_id" {}

variable "aws_region" {}

variable "private_subnet_ids" {}

variable "private_sg" {}

variable "kubernetes_version" {
  description = "Cluster Kubernetes version"
  default     = "1.25"
}
