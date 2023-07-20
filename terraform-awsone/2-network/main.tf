module "network" {
  source               = "./vpc"
  access_ip            = var.access_ip
  environment          = var.environment
  vpc_cidr             = local.vpc_cidr
  public_subnets_cidr  = local.public_subnets_cidr
  private_subnets_cidr = local.private_subnets_cidr
  security_groups      = local.security_groups
}
