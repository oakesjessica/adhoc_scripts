terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = var.aws_credentials_file_path
  profile                 = var.aws_credentials_profile
}

/*==============================================================================
                                  VPC
==============================================================================*/
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-vpc"
  }
}

/*==============================================================================
                           PUBLIC SUBNET
==============================================================================*/
# Public Subnet
resource "aws_subnet" "subnet-public" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = "us-east-1a" # TODO: make dynamic
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-subnet-public"
  }
}

## Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-igw"
  }
}

## Routing Table
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.vpc.id
  # See https://www.terraform.io/language/attr-as-blocks for syntax
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-public-crt"
  }
}

## Routing table associations
resource "aws_route_table_association" "public-rt-association" {
  route_table_id = aws_route_table.public-rt.id
  subnet_id      = aws_subnet.subnet-public.id
}

/*==============================================================================
                           PRIVATE SUBNET
==============================================================================*/
# Private Subnet
resource "aws_subnet" "subnet-private" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = "us-east-1a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-subnet-private"
  }
}

# EIP/NAT
resource "aws_eip" "private-eip" {
  vpc = true

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-private-eip"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.private-eip.id
  subnet_id     = aws_subnet.subnet-public.id
  # NAT gateway is created in a public subnet so it can give private subnets internet access
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-ngw"
  }
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "private-rt-association" {
  subnet_id      = aws_subnet.subnet-private.id
  route_table_id = aws_route_table.private-rt.id
}

/*==============================================================================
                                BASTION
==============================================================================*/
# EC2 key pair resource to control login
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion-kp" {
  key_name   = "oakes-opi-sandbox"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "local_file" "saveKey" {
  content  = tls_private_key.private_key.private_key_pem
  filename = "./bastion-kp.pem"
}

# Security Group
resource "aws_security_group" "bastion-sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "Bastion SSH Security Group"
  description = "Security group for bastion inbound traffic"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"] # limit to user's ip address
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-bastion-sg"
  }
}

# EC2 Instance
resource "aws_instance" "bastion-instance" {
  ami               = var.bastion-ami-id
  instance_type     = "t3a.nano"
  subnet_id         = aws_subnet.subnet-public.id
  availability_zone = "us-east-1a"

  key_name = aws_key_pair.bastion-kp.key_name

  # Instances inside a VPC should use vpc_security_group_ids, see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
  vpc_security_group_ids = [aws_security_group.bastion-sg.id]

  # Need to access via internet
  associate_public_ip_address = true

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-bastion-instance"
  }
}

/*==============================================================================
                                PRIVATE EC2
==============================================================================*/
# Security Group
resource "aws_security_group" "webserver-sg" {
  vpc_id      = aws_vpc.vpc.id
  name        = "Private Webserver Security Group"
  description = "Security group for webserver. Allow traffic from bastion host only"

  ingress {
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.bastion-sg.id] # allow SSH from bastion host only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-webserver-sg"
  }
}

# EC2 Instance
resource "aws_instance" "webserver-instance" {
  ami               = var.linux-ami-id
  instance_type     = "t3a.nano"
  subnet_id         = aws_subnet.subnet-private.id
  availability_zone = "us-east-1a"

  key_name = aws_key_pair.bastion-kp.key_name

  vpc_security_group_ids = [aws_security_group.webserver-sg.id]

  tags = {
    Name = "${var.tag_name_prefix}-${var.environment}-webserver-instance"
  }
}
