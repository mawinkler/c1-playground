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

variable "create_ecs" {
  default = true
}

variable "create_eks" {
  default = false
}
