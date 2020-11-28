resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "ecs-deploy"
  }
}

# == Subnet ===============================================
resource "aws_subnet" "public-subnet" {
  count = length(var.availability_zone)

  vpc_id            = aws_vpc.main.id
  availability_zone = var.availability_zone[count.index]
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 4, 8 + count.index)

  tags = {
    Name = "ecs-deploy-public-${count.index}"
  }
}

resource "aws_subnet" "private-subnet" {
  count = length(var.availability_zone)

  vpc_id            = aws_vpc.main.id
  availability_zone = var.availability_zone[count.index]
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 3, count.index)

  tags = {
    Name = "ecs-deploy-private-${count.index}"
  }
}
# =========================================================


# == Gateways =============================================
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ecs-deploy"
  }
}

resource "aws_nat_gateway" "ecs-public" {
  count = length(var.availability_zone)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public-subnet[count.index].id

  depends_on = [aws_subnet.public-subnet]

  tags = {
    Name = "ecs-deploy-nat-gw-${count.index}"
  }
}

resource "aws_eip" "nat" {
  count = length(var.availability_zone)

  vpc = true

  tags = {
    Name = "ecs-deploy-nat-eip-${count.index}"
  }
}
# =========================================================

# == Route Tables =========================================
resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "ecs-deploy-public-route"
  }
}

resource "aws_route_table_association" "public-route" {
  count = length(var.availability_zone)

  subnet_id      = aws_subnet.public-subnet[count.index].id
  route_table_id = aws_route_table.public-route.id
}

resource "aws_route_table" "private-route" {
  count = length(var.availability_zone)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ecs-public[count.index].id
  }

  tags = {
    Name = "ecs-deploy-private-route-${count.index}"
  }
}

resource "aws_route_table_association" "private-route" {
  count = length(var.availability_zone)

  subnet_id      = aws_subnet.private-subnet[count.index].id
  route_table_id = aws_route_table.private-route[count.index].id
}
# =========================================================
