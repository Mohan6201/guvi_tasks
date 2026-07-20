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
# Input variables — all values come from the environment (TF_VAR_*)
# -------------------------------------------------------------------

variable "region_1" {
  description = "Primary AWS region"
  type        = string
}

variable "region_2" {
  description = "Secondary AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name_region_1" {
  description = "Key pair name in region 1"
  type        = string
}

variable "key_name_region_2" {
  description = "Key pair name in region 2"
  type        = string
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

# -------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------

output "instance_region_1_id" {
  description = "Instance ID in region 1"
  value       = aws_instance.ec2_region_1.id
}

output "instance_region_1_public_ip" {
  description = "Public IP of the EC2 instance in region 1"
  value       = aws_instance.ec2_region_1.public_ip
}

output "instance_region_2_id" {
  description = "Instance ID in region 2"
  value       = aws_instance.ec2_region_2.id
}

output "instance_region_2_public_ip" {
  description = "Public IP of the EC2 instance in region 2"
  value       = aws_instance.ec2_region_2.public_ip
}

output "ssh_region_1" {
  description = "SSH command for region 1 instance"
  value       = "ssh -i ~/.ssh/${var.key_name_region_1}.pem ec2-user@${aws_instance.ec2_region_1.public_ip}"
}

output "ssh_region_2" {
  description = "SSH command for region 2 instance"
  value       = "ssh -i ~/.ssh/${var.key_name_region_2}.pem ec2-user@${aws_instance.ec2_region_2.public_ip}"
}
