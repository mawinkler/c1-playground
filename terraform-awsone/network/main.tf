# create an IGW (Internet Gateway)
# It enables your vpc to connect to the internet
resource "aws_internet_gateway" "pg_igw" {
    vpc_id = "${aws_vpc.pg_vpc.id}"

    tags = {
        Name = "pg-igw"
    }
}

# create a custom route table for public subnets
# public subnets can reach to the internet buy using this
resource "aws_route_table" "pg_public_crt" {
    vpc_id = "${aws_vpc.pg_vpc.id}"
    route {
        cidr_block = "0.0.0.0/0" //associated subnet can reach everywhere
        gateway_id = "${aws_internet_gateway.pg_igw.id}" //CRT uses this IGW to reach internet
    }

    tags = {
        Name = "pg-public-crt"
    }
}

# route table association for the public subnets
resource "aws_route_table_association" "pg_crta_public_subnet" {
    subnet_id = "${aws_subnet.pg_public_subnet.id}"
    route_table_id = "${aws_route_table.pg_public_crt.id}"
}

# security group
resource "aws_security_group" "pg_sg" {
    for_each    = var.security_groups
    name        = each.value.name
    description = each.value.description
    vpc_id = "${aws_vpc.pg_vpc.id}"

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

    # ingress {
    #     from_port = 22
    #     to_port = 22
    #     protocol = "tcp"
        
    #     // This means, all ip address are allowed to ssh !
    #     // Do not do it in the production. Put your office or home address in it!
    #     cidr_blocks = ["0.0.0.0/0"]
    # }

    # //If you do not add this rule, you can not reach the NGIX
    # ingress {
    #     from_port = 80
    #     to_port = 80
    #     protocol = "tcp"
    #     cidr_blocks = ["0.0.0.0/0"]
    # }

    tags = {
        Name = "pg-sg"
    }
}
