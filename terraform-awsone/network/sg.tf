# #############################################################################
# Create
#   Security Group
# #############################################################################
resource "aws_security_group" "sg" {
    for_each    = var.security_groups
    name        = each.value.name
    description = each.value.description
    vpc_id = "${aws_vpc.vpc.id}"

    dynamic "ingress" {
        for_each = each.value.ingress

        content {
        from_port   = ingress.value.from
        to_port     = ingress.value.to
        protocol    = ingress.value.protocol
        cidr_blocks = ingress.value.cidr_blocks
        }
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name        = "${var.environment}-security-group"
        Environment = "${var.environment}"
    }
}
