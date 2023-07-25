data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../2-network/terraform.tfstate"
  }
}

module "ecs" {
  source                    = "./ecs"
  environment               = var.environment
  account_id                = var.account_id
  aws_region                = var.aws_region
  access_ip                 = var.access_ip
  vpc_id                    = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnet_ids         = data.terraform_remote_state.vpc.outputs.public_subnet_ids.*
  private_subnet_ids        = data.terraform_remote_state.vpc.outputs.private_subnet_ids.*
  private_security_group_id = data.terraform_remote_state.vpc.outputs.private_security_group_id
}
