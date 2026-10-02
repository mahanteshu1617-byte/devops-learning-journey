# ═══════════════════════════════════════════
# HCA VPC — 3-Tier Architecture with Security
# ═══════════════════════════════════════════

provider "aws" {
  region = "ap-south-1"
}

# ─── VPC ───
resource "aws_vpc" "hca_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "hca-vpc"
    Project = "HCA-Learning"
  }
}

# ─── SUBNETS ───
resource "aws_subnet" "hca_public_subnet" {
  vpc_id                  = aws_vpc.hca_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = { Name = "hca-public-subnet" }
}

resource "aws_subnet" "hca_app_subnet" {
  vpc_id            = aws_vpc.hca_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1a"

  tags = { Name = "hca-app-subnet" }
}

resource "aws_subnet" "hca_data_subnet" {
  vpc_id            = aws_vpc.hca_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"

  tags = { Name = "hca-data-subnet" }
}

# ─── INTERNET GATEWAY ───
resource "aws_internet_gateway" "hca_igw" {
  vpc_id = aws_vpc.hca_vpc.id
  tags   = { Name = "hca-igw" }
}

# ─── ROUTE TABLES ───
resource "aws_route_table" "hca_public_rt" {
  vpc_id = aws_vpc.hca_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hca_igw.id
  }

  tags = { Name = "hca-public-rt" }
}

resource "aws_route_table" "hca_private_rt" {
  vpc_id = aws_vpc.hca_vpc.id
  tags   = { Name = "hca-private-rt" }
}

# ─── ROUTE TABLE ASSOCIATIONS ───
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.hca_public_subnet.id
  route_table_id = aws_route_table.hca_public_rt.id
}

resource "aws_route_table_association" "app_assoc" {
  subnet_id      = aws_subnet.hca_app_subnet.id
  route_table_id = aws_route_table.hca_private_rt.id
}

resource "aws_route_table_association" "data_assoc" {
  subnet_id      = aws_subnet.hca_data_subnet.id
  route_table_id = aws_route_table.hca_private_rt.id
}

# ─── SECURITY GROUPS ───

# ALB Security Group — public HTTPS
resource "aws_security_group" "alb_sg" {
  name        = "hca-alb-sg"
  description = "Allow HTTPS from internet"
  vpc_id      = aws_vpc.hca_vpc.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hca-alb-sg" }
}

# App Security Group — from ALB only
resource "aws_security_group" "app_sg" {
  name        = "hca-app-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = aws_vpc.hca_vpc.id

  ingress {
    description     = "App port from ALB SG"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hca-app-sg" }
}

# DB Security Group — from App only
resource "aws_security_group" "db_sg" {
  name        = "hca-db-sg"
  description = "Allow MySQL from App SG only"
  vpc_id      = aws_vpc.hca_vpc.id

  ingress {
    description     = "MySQL from App SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hca-db-sg" }
}
