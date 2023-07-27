locals {
  vpc_cidr             = "10.0.0.0/16"
  public_subnets_cidr  = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
  private_subnets_cidr = ["10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19"]
}

locals {
  security_groups = {
    public = {
      name        = "public_sg"
      description = "Security group for Public Access"
      ingress = {
        ssh = {
          from        = 22
          to          = 22
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        http = {
          from        = 80
          to          = 80
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        https = {
          from        = 443
          to          = 443
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        rdp = {
          from        = 3389
          to          = 3389
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        winrm = {
          description = "WinRM Access"
          from        = 5985
          to          = 5986
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        http = {
          from        = 8080
          to          = 8080
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
      }
    }

    private = {
      name        = "private_sg"
      description = "Security group"
      ingress = {
        ssh = {
          from        = 22
          to          = 22
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        http = {
          from        = 80
          to          = 80
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        https = {
          from        = 443
          to          = 443
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        rdp = {
          from        = 3389
          to          = 3389
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        winrm = {
          description = "WinRM Access"
          from        = 5985
          to          = 5986
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
        http = {
          from        = 8080
          to          = 8080
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
      }
    }
  }
}
