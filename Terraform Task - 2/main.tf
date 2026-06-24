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
  alias  = "us_east_1"
  region = var.region_1
}

provider "aws" {
  alias  = "us_west_2"
  region = var.region_2
}

# -------------------------------------------------------------------
# Fetch latest Amazon Linux 2 AMI in each region
# -------------------------------------------------------------------

data "aws_ami" "amazon_linux_east" {
  provider    = aws.us_east_1
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_ami" "amazon_linux_west" {
  provider    = aws.us_west_2
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# -------------------------------------------------------------------
# User data — installs and starts nginx
# -------------------------------------------------------------------

locals {
  nginx_user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install nginx1 -y
    systemctl start nginx
    systemctl enable nginx
  EOF
}

# -------------------------------------------------------------------
# Security group — region 1 (us-east-1)
# -------------------------------------------------------------------

resource "aws_security_group" "nginx_sg_east" {
  provider    = aws.us_east_1
  name        = "nginx-sg-us-east-1"
  description = "Allow HTTP and SSH"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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

  tags = {
    Name = "nginx-sg-us-east-1"
  }
}

# -------------------------------------------------------------------
# Security group — region 2 (us-west-2)
# -------------------------------------------------------------------

resource "aws_security_group" "nginx_sg_west" {
  provider    = aws.us_west_2
  name        = "nginx-sg-us-west-2"
  description = "Allow HTTP and SSH"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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

  tags = {
    Name = "nginx-sg-us-west-2"
  }
}

# -------------------------------------------------------------------
# EC2 instance — region 1 (us-east-1)
# -------------------------------------------------------------------

resource "aws_instance" "nginx_east" {
  provider               = aws.us_east_1
  ami                    = data.aws_ami.amazon_linux_east.id
  instance_type          = var.instance_type
  key_name               = var.key_name_region_1
  vpc_security_group_ids = [aws_security_group.nginx_sg_east.id]
  user_data              = local.nginx_user_data

  tags = {
    Name   = "nginx-server-us-east-1"
    Region = "us-east-1"
  }
}

# -------------------------------------------------------------------
# EC2 instance — region 2 (us-west-2)
# -------------------------------------------------------------------

resource "aws_instance" "nginx_west" {
  provider               = aws.us_west_2
  ami                    = data.aws_ami.amazon_linux_west.id
  instance_type          = var.instance_type
  key_name               = var.key_name_region_2
  vpc_security_group_ids = [aws_security_group.nginx_sg_west.id]
  user_data              = local.nginx_user_data

  tags = {
    Name   = "nginx-server-us-west-2"
    Region = "us-west-2"
  }
}
