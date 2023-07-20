data "terraform_remote_state" "vpc" {
    backend = "local"

    config = {
        path = "../2-network/terraform.tfstate"
    }
}

module "ec2" {
    source           = "./ec2"
    environment      = var.environment
    public_sg        = data.terraform_remote_state.vpc.outputs.public_sg
    public_subnet    = data.terraform_remote_state.vpc.outputs.public_subnet.*
    ec2_profile      = module.iam.ec2_profile
    s3_bucket        = module.s3.s3_bucket
    linux_username   = var.linux_username
    windows_username = var.windows_username
    create_linux     = var.create_linux
    create_windows   = var.create_windows
}

module "iam" {
    source           = "./iam"
    s3_bucket        = module.s3.s3_bucket
}

module "s3" {
    source           = "./s3"
}
