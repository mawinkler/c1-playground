# #############################################################################
# Variables
# #############################################################################
# Container Security
variable "cluster_policy" {}

variable "environment" {}

# Cloud One
variable "cloud_one_region" {}

variable "cloud_one_instance" {
  default = "cloudone"
}

variable "api_key" {}

variable "namespace" {
  default = "trendmicro-system"
}
