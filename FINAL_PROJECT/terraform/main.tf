# terraform/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Point Terraform to LocalStack instead of real AWS
provider "aws" {
  region = "us-east-1"
  profile = "infra-engineer"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2             = "http://localhost:4566"
    iam             = "http://localhost:4566"
    sts             = "http://localhost:4566"
    elasticloadbalancing = "http://localhost:4566"
  }
}

# ─────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name    = "homelab-vpc"
    Project = "homelab-devops"
  }
}

# ─────────────────────────────────────────────
# Subnets
# ─────────────────────────────────────────────
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet"
  }
}

# ─────────────────────────────────────────────
# Internet Gateway
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "homelab-igw"
  }
}

# ─────────────────────────────────────────────
# Elastic IP + NAT Gateway
# ─────────────────────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "homelab-nat"
  }
}

# ─────────────────────────────────────────────
# Route tables
# ─────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ─────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────
resource "aws_security_group" "jump" {
  name        = "jump-server-sg"
  description = "Jump server - SSH only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jump-server-sg" }
}

resource "aws_security_group" "lb" {
  name        = "lb-sg"
  description = "Load balancer - HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lb-sg" }
}

resource "aws_security_group" "private" {
  name        = "private-ec2-sg"
  description = "Private EC2 - HTTP from LB, SSH from jump"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jump.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "private-ec2-sg" }
}

# ─────────────────────────────────────────────
# EC2 Instances
# ─────────────────────────────────────────────
resource "aws_instance" "jump" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.jump.id]

  tags = {
    Name    = "jump-server"
    Role    = "bastion"
    Project = "homelab-devops"
  }
}

resource "aws_instance" "http_server" {
  count                  = var.http_server_count
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private.id]

  tags = {
    Name    = "http-server-${count.index + 1}"
    Role    = "webserver"
    Project = "homelab-devops"
  }
}

# ─────────────────────────────────────────────
# Elastic IP for Jump Server
# ─────────────────────────────────────────────
resource "aws_eip" "jump" {
  instance = aws_instance.jump.id
  domain   = "vpc"

  tags = { Name = "jump-server-eip" }
}

# ─────────────────────────────────────────────
# Data Source 
# ─────────────────────────────────────────────
data "aws_caller_identity" "current" {}