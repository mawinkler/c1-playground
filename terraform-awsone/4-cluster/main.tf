data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../2-network/terraform.tfstate"
  }
}

module "cluster" {
  source             = "./cluster"
  environment        = var.environment
  account_id         = var.account_id
  aws_region         = var.aws_region
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet.*
  private_sg         = data.terraform_remote_state.vpc.outputs.private_sg
}
