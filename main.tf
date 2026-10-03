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

# ═══════════════════════════════════════════
# EC2 — Web Server in Public Subnet
# ═══════════════════════════════════════════

# ─── SSH KEY PAIR ───
# This creates an AWS key pair from a public key you provide.
# Save the private key to your laptop and use it to SSH.
resource "aws_key_pair" "hca_key" {
  key_name   = "hca-web-key"
  public_key = file("~/.ssh/hca-web-key.pub")

  tags = { Name = "hca-web-key" }
}

# ─── WEB SECURITY GROUP ───
# Instance-level firewall. Allows SSH (22) and HTTP (80) from internet.
resource "aws_security_group" "web_sg" {
  name        = "hca-web-sg"
  description = "Allow SSH and HTTP from internet"
  vpc_id      = aws_vpc.hca_vpc.id

  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ⚠️ in prod: restrict to office IP
  }

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hca-web-sg" }
}

# ─── EC2 INSTANCE ───
# The web server. user_data installs nginx on first boot.
resource "aws_instance" "hca_web" {
  ami                    = "ami-0fa52f1a01deb1658"  # Ubuntu 22.04 in ap-south-1
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.hca_public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.hca_key.key_name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    echo "<h1>HCA Web Server - $(hostname -f)</h1>" > /var/www/html/index.html
    systemctl start nginx
    systemctl enable nginx
  EOF

  tags = { Name = "hca-web-server" }
}

# ─── ELASTIC IP ───
# Stable public IP that survives restarts.
resource "aws_eip" "hca_web_eip" {
  instance = aws_instance.hca_web.id
  domain   = "vpc"

  tags = { Name = "hca-web-eip" }
}
