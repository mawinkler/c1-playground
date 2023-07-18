# #############################################################################
# Create Subnets
# #############################################################################
# Elastic IP for NAT
resource "aws_eip" "nat_eip" {
    vpc        = true
    depends_on = [aws_internet_gateway.ig]
}

# #############################################################################
# Create
#   NAT gateway
#   Public subnets
#   Private subnets
# #############################################################################
# NAT Gateway
resource "aws_nat_gateway" "nat" {
    allocation_id = "${aws_eip.nat_eip.id}"
    subnet_id     = "${element(aws_subnet.public_subnet.*.id, 0)}"
    depends_on    = [aws_internet_gateway.ig]

    tags = {
        Name        = "nat"
        Environment = "${var.environment}"
    }
}

# Public subnets
resource "aws_subnet" "public_subnet" {
    vpc_id                  = "${aws_vpc.vpc.id}"
    count                   = "${length(var.public_subnets_cidr)}"
    cidr_block              = "${element(var.public_subnets_cidr, count.index)}"
    # availability_zone       = "${element(var.availability_zones,   count.index)}"
    availability_zone       = "${element(data.aws_availability_zones.available.names, count.index)}"
    map_public_ip_on_launch = true

    tags = {
        Name        = "${var.environment}-${element(data.aws_availability_zones.available.names, count.index)}-public-subnet"
        Environment = "${var.environment}"
    }
}

# Private subnets
resource "aws_subnet" "private_subnet" {
    vpc_id                  = "${aws_vpc.vpc.id}"
    count                   = "${length(var.private_subnets_cidr)}"
    cidr_block              = "${element(var.private_subnets_cidr, count.index)}"
    # availability_zone       = "${element(var.availability_zones,   count.index)}"
    availability_zone       = "${element(data.aws_availability_zones.available.names, count.index)}"
    map_public_ip_on_launch = false

    tags = {
        Name        = "${var.environment}-${element(data.aws_availability_zones.available.names, count.index)}-private-subnet"
        Environment = "${var.environment}"
    }
}
