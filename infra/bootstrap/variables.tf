variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-2"
}

variable "state_bucket_name" {
  description = "S3 bucket holding Terraform remote state for this project."
  type        = string
  default     = "dual-weather-tfstate-us-east-2"
}

variable "lock_table_name" {
  description = "DynamoDB table used for Terraform state locking."
  type        = string
  default     = "dual-weather-tflock"
}
