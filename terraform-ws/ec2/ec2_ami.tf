# #############################################################################
# Look up the latest Ubuntu Focal 20.04 AMI
# #############################################################################
data "aws_ami" "ubuntu" {
    most_recent            = true
    owners                 = ["099720109477"] # Canonical

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    filter {
        name   = "architecture"
        values = ["x86_64"]
    }

    filter {
        name   = "image-type"
        values = ["machine"]
    }

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }
}