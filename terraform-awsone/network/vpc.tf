resource "aws_vpc" "pg_vpc" {
    cidr_block = var.vpc_cidr
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    # enable_classiclink = "false"
    instance_tenancy = "default"

    tags = {
        Name = "pg-vpc"
    }
}

resource "aws_subnet" "pg_public_subnet" {
    vpc_id                  = "${aws_vpc.pg_vpc.id}"
    cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone       = data.aws_availability_zones.available.names[1]


    tags = {
        Name = "pg-public-subnet"
    }
}
