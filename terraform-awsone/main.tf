module "network" {
  source           = "./network"
  access_ip        = var.access_ip
  vpc_cidr         = local.vpc_cidr
  security_groups  = local.security_groups
}

module "ec2" {
  source           = "./ec2"
  public_sg        = module.network.public_sg
  public_subnet    = module.network.public_subnet
  ec2_profile      = module.iam.ec2_profile
  s3_bucket        = module.s3.s3_bucket
  linux_username   = var.linux_username
  windows_username = var.windows_username
  windows_password = var.windows_password
  create_linux     = var.create_linux
  create_windows   = var.create_windows
}

module "iam" {
  source           = "./iam"
  account_id       = var.account_id
  s3_bucket        = module.s3.s3_bucket
}

module "s3" {
  source           = "./s3"
}