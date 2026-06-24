terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

# -------------------------------------------------------------------
# Providers — one alias per region
# -------------------------------------------------------------------

provider "aws" {
  alias  = "region_1"
  region = var.region_1
}

provider "aws" {
  alias  = "region_2"
  region = var.region_2
}

# -------------------------------------------------------------------
# Fetch latest Amazon Linux 2 AMI in each region
# -------------------------------------------------------------------

data "aws_ami" "linux_region_1" {
  provider    = aws.region_1
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_ami" "linux_region_2" {
  provider    = aws.region_2
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# -------------------------------------------------------------------
# Security group — region 1
# -------------------------------------------------------------------

resource "aws_security_group" "ec2_sg_region_1" {
  provider    = aws.region_1
  name        = "ec2-sg-${var.region_1}"
  description = "Allow SSH"

  ingress {
    description = "SSH"
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

  tags = {
    Name = "ec2-sg-${var.region_1}"
  }
}

# -------------------------------------------------------------------
# Security group — region 2
# -------------------------------------------------------------------

resource "aws_security_group" "ec2_sg_region_2" {
  provider    = aws.region_2
  name        = "ec2-sg-${var.region_2}"
  description = "Allow SSH"

  ingress {
    description = "SSH"
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

  tags = {
    Name = "ec2-sg-${var.region_2}"
  }
}

# -------------------------------------------------------------------
# EC2 instance — region 1
# -------------------------------------------------------------------

resource "aws_instance" "ec2_region_1" {
  provider               = aws.region_1
  ami                    = data.aws_ami.linux_region_1.id
  instance_type          = var.instance_type
  key_name               = var.key_name_region_1
  vpc_security_group_ids = [aws_security_group.ec2_sg_region_1.id]

  tags = {
    Name   = "linux-ec2-${var.region_1}"
    Region = var.region_1
  }
}

# -------------------------------------------------------------------
# EC2 instance — region 2
# -------------------------------------------------------------------

resource "aws_instance" "ec2_region_2" {
  provider               = aws.region_2
  ami                    = data.aws_ami.linux_region_2.id
  instance_type          = var.instance_type
  key_name               = var.key_name_region_2
  vpc_security_group_ids = [aws_security_group.ec2_sg_region_2.id]

  tags = {
    Name   = "linux-ec2-${var.region_2}"
    Region = var.region_2
  }
}
