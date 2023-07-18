# #############################################################################
# Create
#   Internet Gateway
# #############################################################################
# It enables your vpc to connect to the internet
resource "aws_internet_gateway" "ig" {
    vpc_id = "${aws_vpc.vpc.id}"

    tags = {
        Name        = "${var.environment}-igw"
        Environment = "${var.environment}"
    }
}