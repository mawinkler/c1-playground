variable "aws_region" {
  type = string
}

variable "access_ip" {
  type = string
}

variable "s3_bucket" {
  type    = string
  default = "playground-awsone"
}

variable "linux_username" {
  type = string
}

variable "windows_username" {
  type = string
}

variable "windows_password" {
    type    = string
    default = ""
}

variable "create_linux" {
  type = bool
}

variable "create_windows" {
  type = bool
}

variable "create_cluster" {
  type = bool
}

variable "environment" {
  type    = string
  default = "playground"
}