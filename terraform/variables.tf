variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-west-2"
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

variable "ne_vande_db_password" {
  description = "Password for the ne_vande database admin user"
  type        = string
  sensitive   = true
}

variable "vitality_db_password" {
  description = "Password for the vitality database admin user"
  type        = string
  sensitive   = true
}

variable "proaging360_db_password" {
  description = "Password for the proaging360 database admin user"
  type        = string
  sensitive   = true
}

variable "db_allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect to the RDS instances on port 3306"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}
