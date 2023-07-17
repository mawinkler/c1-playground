variable "aws_region" {
  type = string
}

variable "access_ip" {
  type = string
}

variable "account_id" {
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
  type = string
}

variable "create_linux" {
  type = bool
}

variable "create_windows" {
  type = bool
}
