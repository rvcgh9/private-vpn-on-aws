resource "aws_vpc" "vpn_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name"    = "${var.project_name}-vpc"
    "Project" = var.project_name
  }
}

resource "aws_network_acl" "network_acl" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    "Name"    = "${var.project_name}-network-acl"
    "Project" = var.project_name
  }
}

resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidr_blocks)

  vpc_id            = aws_vpc.vpn_vpc.id
  cidr_block        = var.public_subnet_cidr_blocks[count.index]
  availability_zone = var.availability_zones[count.index%3]

  tags = {
    "Name"    = "${var.project_name}-public-subnet-${count.index}"
    "Project" = var.project_name
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    "Name"    = "${var.project_name}-ig"
    "Project" = var.project_name
  }
}

resource "aws_route_table" "public_subnet_route_table" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    "Name"    = "${var.project_name}-public-subnet-rt"
    "Project" = var.project_name
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  count          = length(var.public_subnet_cidr_blocks)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_subnet_route_table.id
}

resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidr_blocks)

  vpc_id            = aws_vpc.vpn_vpc.id
  cidr_block        = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone = element(var.availability_zones, count.index%3)

  tags = {
    "Name"    = "${var.project_name}-private-subnet-${count.index}"
    "Project" = var.project_name
  }
}

resource "aws_eip" "nat_gateway_ip" {
  count = length(var.private_subnet_cidr_blocks)

  tags = {
    "Name"    = "${var.project_name}-eip-${count.index}"
    "Project" = var.project_name
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  count = length(var.private_subnet_cidr_blocks)

  subnet_id     = element(var.public_subnet_cidr_blocks, count.index)
  allocation_id = element(aws_eip.nat_gateway_ip[*].id, count.index)

  tags = {
    "Name"    = "${var.project_name}-nat-gateway-${count.index}"
    "Project" = var.project_name
  }
}

resource "aws_route_table" "private_subnet_route_tables" {
  count  = length(var.private_subnet_cidr_blocks)
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat_gateway[*].id, count.index)
  }

  tags = {
    "Name"    = "${var.project_name}-private-subnet-rt"
    "Project" = var.project_name
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = length(var.private_subnet_cidr_blocks)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = element(aws_route_table.private_subnet_route_tables[*].id, count.index)
}
