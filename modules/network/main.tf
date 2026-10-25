locals {
  name      = "${var.owner}-${var.environment}"
  nat_count = var.single_nat_gateway ? 1 : length(var.azs)

  # 10.x.0.0/24, 10.x.1.0/24
  public_cidrs = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  # 10.x.16.0/20, 10.x.32.0/20 (room for EKS pod IPs)
  private_cidrs = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 4, i + 1)]
  # 10.x.100.0/24, 10.x.101.0/24
  db_cidrs = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 8, 100 + i)]

  interface_endpoints = ["ecr.api", "ecr.dkr", "secretsmanager", "logs", "sts"]
}

data "aws_region" "current" {}

# ---------- VPC ----------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

# ---------- Public subnets: ALB, NAT ----------
resource "aws_subnet" "public" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.public_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name                                            = "${local.name}-public-${var.azs[count.index]}"
    Tier                                            = "public"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${local.name}-rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------- NAT (egress for private subnets) ----------
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${local.name}-nat-${var.azs[count.index]}" }
  depends_on    = [aws_internet_gateway.this]
}

# ---------- Private subnets: EKS ----------
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name                                            = "${local.name}-private-${var.azs[count.index]}"
    Tier                                            = "private"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[min(count.index, local.nat_count - 1)].id
  }
  tags = { Name = "${local.name}-rt-private-${var.azs[count.index]}" }
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ---------- Isolated DB subnets: NO internet route ----------
resource "aws_subnet" "db" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.db_cidrs[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name = "${local.name}-db-${var.azs[count.index]}"
    Tier = "isolated-db"
  }
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.this.id
  # Intentionally no 0.0.0.0/0 route: only the implicit local VPC route.
  tags = { Name = "${local.name}-rt-db-isolated" }
}

resource "aws_route_table_association" "db" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# ---------- VPC endpoints ----------
# S3 gateway endpoint: free; keeps S3 traffic (state, Loki, ECR layers) on the AWS network
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private[*].id, [aws_route_table.db.id])
  tags              = { Name = "${local.name}-vpce-s3" }
}

resource "aws_security_group" "endpoints" {
  count       = var.enable_interface_endpoints ? 1 : 0
  name        = "${local.name}-vpce"
  description = "HTTPS from inside the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${local.name}-vpce-sg" }
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = var.enable_interface_endpoints ? toset(local.interface_endpoints) : toset([])
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true
  tags                = { Name = "${local.name}-vpce-${each.key}" }
}
