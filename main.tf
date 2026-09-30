terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

# VPC
resource "aws_vpc" "ykVPC" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "SecurityLab-VPC"
    Environment = "Dev"
    ManagedBy   = "YK"
  }
}

# Public Subnet
resource "aws_subnet" "publicSubnet" {
  vpc_id                  = aws_vpc.ykVPC.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "SecurityLab-Public-Subnet"
  }
}

# Private Subnet (NOTE: there will be no resources here, just demonstrate, because required NAT gateway has signifficant cost)
resource "aws_subnet" "privateSubnet" {
  vpc_id            = aws_vpc.ykVPC.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "SecurityLab-Private-Subnet"
  }
}

# IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ykVPC.id

  tags = {
    Name = "SecurityLab-IGW"
  }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ykVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "SecurityLab-Public-RT"
  }
}

# Route table association
resource "aws_route_table_association" "publicAccess" {
  subnet_id      = aws_subnet.publicSubnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Choose Instance
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# EC2 instance
resource "aws_instance" "test_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.publicSubnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm_profile.name
  associate_public_ip_address = true

  tags = {
    Name        = "SecurityLab-Test-Server"
    Environment = "Dev"
  }
}

# Security Groups
resource "aws_security_group" "web_sg" {
  name        = "hardened-web-sg"
  description = "Restrict inbound/outbound traffic to HTTPS only"
  vpc_id      = aws_vpc.ykVPC.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# isolated SG
resource "aws_security_group" "isolated_sg" {
  name        = "isolated-web-sg"
  description = "Isolate EC2 from network access"
  vpc_id      = aws_vpc.ykVPC.id

  ingress = []
  egress  = []
}