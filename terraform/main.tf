terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "primary" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "primary-subnet"
  }
}

resource "aws_subnet" "secondary" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "secondary-subnet"
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "main-db-subnet-group"
  subnet_ids = [aws_subnet.primary.id, aws_subnet.secondary.id]

  tags = {
    Name = "main-db-subnet-group"
  }
}

locals {
  db_identifiers = { for name in nonsensitive(toset(keys(var.db_passwords))) : name => "${replace(name, "_", "-")}-db" }
}

resource "aws_db_instance" "databases" {
  for_each = local.db_identifiers

  identifier             = each.value
  engine                 = "mysql"
  engine_version         = var.mysql_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  db_name                = each.key
  username               = "admin"
  password               = var.db_passwords[each.key]
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.default.id]
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.default.arn
  skip_final_snapshot    = true

  tags = {
    Name = each.value
  }
}

resource "aws_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.db_allowed_cidr_blocks
    description = "MySQL access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "default-sg"
  }
}

resource "aws_kms_key" "default" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

output "db_endpoints" {
  description = "The connection endpoints for all database instances, keyed by database name"
  value       = { for k, v in aws_db_instance.databases : k => v.endpoint }
}

output "vpc_id" {
  description = "The ID of the main VPC"
  value       = aws_vpc.main.id
}

output "db_subnet_group_name" {
  description = "The name of the DB subnet group"
  value       = aws_db_subnet_group.default.name
}

output "security_group_id" {
  description = "The ID of the default security group"
  value       = aws_security_group.default.id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for RDS encryption"
  value       = aws_kms_key.default.arn
}