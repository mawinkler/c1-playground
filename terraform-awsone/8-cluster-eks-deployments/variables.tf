# ####################################
# Variables
# ####################################
# Container Security
variable "cluster_policy" {
  type    = string
}

variable "environment" {
  type    = string
}

# Cloud One
variable "cloud_one_region" {
  type    = string
}

variable "cloud_one_instance" {
  type    = string
}

variable "api_key" {
  type    = string
}
