variable "aws_region" {
  default = "eu-central-1"
}

variable "public_key_path" {
  default = "cnctraining-key-pair.pub"
}

variable "private_key_path" {
  default = "cnctraining-key-pair"
}

variable "access_ip" {
  type = string
}

variable "xbc_agent_url" {
    default = "${V1_XBC_AGENT_URL}"
}