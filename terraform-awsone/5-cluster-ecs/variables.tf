variable "aws_region" {
  type = string
}

variable "access_ip" {
  type = string
}

variable "account_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "ws_tenantid" {
  type = string
  default = ""
}

variable "ws_token" {
  type = string
  default = ""
}

variable "ws_policyid" {
  type = number
  default = 0
}
