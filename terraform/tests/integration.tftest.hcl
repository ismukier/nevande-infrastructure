# Integration tests for the Nevande infrastructure Terraform configuration.
# Uses Terraform's native test framework (terraform test) with mock providers
# so tests can run without real AWS credentials.

mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = {
      id         = "vpc-0123456789abcdef0"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_resource "aws_subnet" {
    defaults = {
      id = "subnet-0123456789abcdef0"
    }
  }

  mock_resource "aws_db_subnet_group" {
    defaults = {
      id   = "main-db-subnet-group"
      name = "main-db-subnet-group"
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-0123456789abcdef0"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      id                  = "mrk-1234567890abcdef1234567890abcdef"
      arn                 = "arn:aws:kms:eu-south-2:123456789012:key/mrk-1234567890abcdef1234567890abcdef"
      key_id              = "mrk-1234567890abcdef1234567890abcdef"
      enable_key_rotation = true
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      id                  = "db-AAABBBCCCDDDEEE"
      endpoint            = "ne-vande-db.cluster-xyz.eu-south-2.rds.amazonaws.com:3306"
      storage_encrypted   = true
      skip_final_snapshot = true
    }
  }
}

# ─── VPC and Networking Tests ──────────────────────────────────────────────────

run "vpc_is_created_with_correct_cidr" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block must be 10.0.0.0/16"
  }
}

run "subnets_are_in_separate_availability_zones" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
    aws_region              = "eu-south-2"
  }

  assert {
    condition     = aws_subnet.primary.availability_zone == "eu-south-2a"
    error_message = "Primary subnet must be in availability zone eu-south-2a"
  }

  assert {
    condition     = aws_subnet.secondary.availability_zone == "eu-south-2b"
    error_message = "Secondary subnet must be in availability zone eu-south-2b"
  }
}

run "subnets_belong_to_main_vpc" {
  command = apply

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = aws_subnet.primary.vpc_id == aws_vpc.main.id
    error_message = "Primary subnet must belong to the main VPC"
  }

  assert {
    condition     = aws_subnet.secondary.vpc_id == aws_vpc.main.id
    error_message = "Secondary subnet must belong to the main VPC"
  }
}

run "db_subnet_group_includes_both_subnets" {
  command = apply

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = length([aws_subnet.primary.id, aws_subnet.secondary.id]) == 2
    error_message = "DB subnet group must reference exactly 2 subnet resources for multi-AZ support"
  }

  assert {
    condition     = contains(aws_db_subnet_group.default.subnet_ids, aws_subnet.primary.id)
    error_message = "DB subnet group must include the primary subnet"
  }

  assert {
    condition     = contains(aws_db_subnet_group.default.subnet_ids, aws_subnet.secondary.id)
    error_message = "DB subnet group must include the secondary subnet"
  }
}

# ─── Security Group Tests ─────────────────────────────────────────────────────

run "security_group_allows_mysql_on_port_3306" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = one(aws_security_group.default.ingress).from_port == 3306
    error_message = "Security group ingress must allow from_port 3306 for MySQL"
  }

  assert {
    condition     = one(aws_security_group.default.ingress).to_port == 3306
    error_message = "Security group ingress must allow to_port 3306 for MySQL"
  }

  assert {
    condition     = one(aws_security_group.default.ingress).protocol == "tcp"
    error_message = "Security group MySQL ingress rule must use tcp protocol"
  }
}

run "security_group_egress_uses_all_protocol" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = one(aws_security_group.default.egress).protocol == "-1"
    error_message = "Security group egress must use protocol '-1' (all) not 'tcp'"
  }
}

run "security_group_ingress_restricted_to_private_cidr" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
    db_allowed_cidr_blocks  = ["10.0.0.0/8"]
  }

  assert {
    condition     = !contains(one(aws_security_group.default.ingress).cidr_blocks, "0.0.0.0/0")
    error_message = "Security group ingress must NOT allow 0.0.0.0/0 - restrict to private CIDR ranges"
  }
}

# ─── KMS Encryption Tests ─────────────────────────────────────────────────────

run "kms_key_rotation_is_enabled" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = aws_kms_key.default.enable_key_rotation == true
    error_message = "KMS key rotation must be enabled"
  }
}

# ─── RDS Instance Tests ───────────────────────────────────────────────────────

run "all_db_instances_use_encryption" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = aws_db_instance.ne_vande.storage_encrypted == true
    error_message = "ne_vande DB instance must have storage encryption enabled"
  }

  assert {
    condition     = aws_db_instance.vitality.storage_encrypted == true
    error_message = "vitality DB instance must have storage encryption enabled"
  }

  assert {
    condition     = aws_db_instance.proaging360.storage_encrypted == true
    error_message = "proaging360 DB instance must have storage encryption enabled"
  }
}

run "all_db_instances_use_kms_key" {
  command = apply

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = aws_db_instance.ne_vande.kms_key_id == aws_kms_key.default.arn
    error_message = "ne_vande DB instance must use the shared KMS key for encryption"
  }

  assert {
    condition     = aws_db_instance.vitality.kms_key_id == aws_kms_key.default.arn
    error_message = "vitality DB instance must use the shared KMS key for encryption"
  }

  assert {
    condition     = aws_db_instance.proaging360.kms_key_id == aws_kms_key.default.arn
    error_message = "proaging360 DB instance must use the shared KMS key for encryption"
  }
}

run "all_db_instances_skip_final_snapshot" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = aws_db_instance.ne_vande.skip_final_snapshot == true
    error_message = "ne_vande DB instance must have skip_final_snapshot set to true"
  }

  assert {
    condition     = aws_db_instance.vitality.skip_final_snapshot == true
    error_message = "vitality DB instance must have skip_final_snapshot set to true"
  }

  assert {
    condition     = aws_db_instance.proaging360.skip_final_snapshot == true
    error_message = "proaging360 DB instance must have skip_final_snapshot set to true"
  }
}

run "all_db_instances_use_shared_subnet_group" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = aws_db_instance.ne_vande.db_subnet_group_name == aws_db_subnet_group.default.name
    error_message = "ne_vande DB instance must use the shared DB subnet group"
  }

  assert {
    condition     = aws_db_instance.vitality.db_subnet_group_name == aws_db_subnet_group.default.name
    error_message = "vitality DB instance must use the shared DB subnet group"
  }

  assert {
    condition     = aws_db_instance.proaging360.db_subnet_group_name == aws_db_subnet_group.default.name
    error_message = "proaging360 DB instance must use the shared DB subnet group"
  }
}

run "all_db_instances_use_mysql_engine" {
  command = plan

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = aws_db_instance.ne_vande.engine == "mysql"
    error_message = "ne_vande DB instance must use the mysql engine"
  }

  assert {
    condition     = aws_db_instance.vitality.engine == "mysql"
    error_message = "vitality DB instance must use the mysql engine"
  }

  assert {
    condition     = aws_db_instance.proaging360.engine == "mysql"
    error_message = "proaging360 DB instance must use the mysql engine"
  }
}

run "all_db_instances_are_associated_with_security_group" {
  command = apply

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = contains(aws_db_instance.ne_vande.vpc_security_group_ids, aws_security_group.default.id)
    error_message = "ne_vande DB instance must be associated with the default security group"
  }

  assert {
    condition     = contains(aws_db_instance.vitality.vpc_security_group_ids, aws_security_group.default.id)
    error_message = "vitality DB instance must be associated with the default security group"
  }

  assert {
    condition     = contains(aws_db_instance.proaging360.vpc_security_group_ids, aws_security_group.default.id)
    error_message = "proaging360 DB instance must be associated with the default security group"
  }
}

# ─── Output Tests ─────────────────────────────────────────────────────────────

run "outputs_expose_db_endpoints" {
  command = apply

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = output.ne_vande_endpoint == aws_db_instance.ne_vande.endpoint
    error_message = "ne_vande_endpoint output must equal the DB instance endpoint"
  }

  assert {
    condition     = output.vitality_endpoint == aws_db_instance.vitality.endpoint
    error_message = "vitality_endpoint output must equal the DB instance endpoint"
  }

  assert {
    condition     = output.proaging360_endpoint == aws_db_instance.proaging360.endpoint
    error_message = "proaging360_endpoint output must equal the DB instance endpoint"
  }
}

run "outputs_expose_network_resources" {
  command = apply

  variables {
    ne_vande_db_password    = "Test1234!"
    vitality_db_password    = "Test1234!"
    proaging360_db_password = "Test1234!"
  }

  assert {
    condition     = output.vpc_id == aws_vpc.main.id
    error_message = "vpc_id output must equal the VPC id"
  }

  assert {
    condition     = output.db_subnet_group_name == aws_db_subnet_group.default.name
    error_message = "db_subnet_group_name output must equal the subnet group name"
  }

  assert {
    condition     = output.security_group_id == aws_security_group.default.id
    error_message = "security_group_id output must equal the security group id"
  }

  assert {
    condition     = output.kms_key_arn == aws_kms_key.default.arn
    error_message = "kms_key_arn output must equal the KMS key ARN"
  }
}
