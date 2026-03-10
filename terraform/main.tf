provider "aws" {
  region = "us-west-2"  # Change to your preferred region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_db_instance" "ne_vande" {
  identifier = "ne-vande-db"
  engine = "mysql"
  instance_class = "db.t2.micro"
  allocated_storage = 20
  db_name = "ne_vande"
  username = "admin"
  password = "Password123!"
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.default.id]
  storage_encrypted = true
  kms_key_id = aws_kms_key.default.id
}

resource "aws_db_instance" "vitality" {
  identifier = "vitality-db"
  engine = "mysql"
  instance_class = "db.t2.micro"
  allocated_storage = 20
  db_name = "vitality"
  username = "admin"
  password = "Password123!"
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.default.id]
  storage_encrypted = true
  kms_key_id = aws_kms_key.default.id
}

resource "aws_db_instance" "proaging360" {
  identifier = "proaging360-db"
  engine = "mysql"
  instance_class = "db.t2.micro"
  allocated_storage = 20
  db_name = "proaging360"
  username = "admin"
  password = "Password123!"
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.default.id]
  storage_encrypted = true
  kms_key_id = aws_kms_key.default.id
}

resource "aws_security_group" "default" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Change to specific CIDR blocks for security
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "default-sg"
  }
}

resource "aws_kms_key" "default" {
  description = "KMS key for RDS encryption"
}

output "ne_vande_endpoint" {
  value = aws_db_instance.ne_vande.endpoint
}

output "vitality_endpoint" {
  value = aws_db_instance.vitality.endpoint
}

output "proaging360_endpoint" {
  value = aws_db_instance.proaging360.endpoint
}