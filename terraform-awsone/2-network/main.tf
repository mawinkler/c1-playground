module "network" {
  source               = "./vpc"
  environment          = var.environment
  access_ip            = var.access_ip
  vpc_cidr             = local.vpc_cidr
  public_subnets_cidr  = local.public_subnets_cidr
  private_subnets_cidr = local.private_subnets_cidr
  security_groups      = local.security_groups
}
