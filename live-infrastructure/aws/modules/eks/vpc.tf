data "aws_region" "current" {}

locals {
  cluster_name = "eks-${var.team_name}-${var.project_name}-${var.env_name}"

  # var.tags porte deja Team/Env/ManagedBy (local.common_tags du root
  # terragrunt.hcl, passe explicitement en input -- pas seulement via le
  # default_tags du provider genere, qui ne s'applique jamais aux blocs
  # imbriques comme aws_launch_template.tag_specifications.tags). On y
  # ajoute juste Project, propre a ce module.
  tags = merge(var.tags, {
    Project = var.project_name
  })
}

resource "aws_vpc" "eks" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "vpc-${var.team_name}-${var.project_name}-${var.env_name}-eks"
  })
}

resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id

  tags = merge(local.tags, {
    Name = "igw-${var.team_name}-${var.project_name}-${var.env_name}-eks"
  })
}

resource "aws_subnet" "eks" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.eks.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                                          = "subnet-${var.team_name}-${var.project_name}-${var.env_name}-eks-${count.index}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  })
}

resource "aws_route_table" "eks" {
  vpc_id = aws_vpc.eks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }

  tags = merge(local.tags, {
    Name = "rt-${var.team_name}-${var.project_name}-${var.env_name}-eks"
  })
}

resource "aws_route_table_association" "eks" {
  count = length(aws_subnet.eks)

  subnet_id      = aws_subnet.eks[count.index].id
  route_table_id = aws_route_table.eks.id
}
