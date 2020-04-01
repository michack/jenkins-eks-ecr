resource "aws_vpc" "env_vpc" {
  cidr_block           = "${var.environment["vpc_cidr"]}"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags                 = "${var.default_tags}"
}

resource "aws_internet_gateway" "env_gw" {
  vpc_id = aws_vpc.env_vpc.id
  tags   = "${var.default_tags}"
}

resource "aws_route_table" "env_public_rt" {
  vpc_id = aws_vpc.env_vpc.id
  tags   = "${var.default_tags}"
}

resource "aws_route" "env_r_gateway" {
  route_table_id         = aws_route_table.env_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.env_gw.id
}

resource "aws_route_table_association" "env_rta_public_subnets_env_public_rt" {
  count          = "${length(var.private_subnet)}"
  subnet_id      = "${element(aws_subnet.private_subnet.*.id, count.index)}"
  route_table_id = aws_route_table.env_public_rt.id
}

resource "aws_subnet" "private_subnet" {
  count                   = "${length(var.private_subnet)}"
  vpc_id                  = aws_vpc.env_vpc.id
  cidr_block              = "${var.private_subnet[count.index]}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = false
  tags                    = "${merge(var.default_tags, map("kubernetes.io/cluster/${var.environment["name"]}-eks", "shared"))}"
}
