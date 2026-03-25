variable "aws_region" {
  description = "The AWS region to deploy resources into (default: eu-south-2, Spain)"
  type        = string
  default     = "eu-south-2"
}

variable "db_instance_class" {
  description = "The instance class for RDS database instances"
  type        = string
  default     = "db.t3.micro"
}

variable "mysql_engine_version" {
  description = "The MySQL engine version to use"
  type        = string
  default     = "8.0"
}

variable "db_passwords" {
  description = "Passwords for each database admin user, keyed by database name (ne_vande, vitality, proaging360)"
  type        = map(string)
  sensitive   = true
}

variable "db_allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect to the RDS instances on port 3306"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}
