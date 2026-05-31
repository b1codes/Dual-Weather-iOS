variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-2"
}

variable "table_name" {
  description = "DynamoDB table name."
  type        = string
  default     = "DualWeather"
}

variable "function_name" {
  description = "Lambda function name."
  type        = string
  default     = "dual-weather-api"
}

variable "log_retention_days" {
  description = "CloudWatch Log Group retention for the Lambda."
  type        = number
  default     = 14
}

variable "state_bucket_name" {
  description = "S3 bucket holding remote state — must match infra/bootstrap output."
  type        = string
  default     = "dual-weather-tfstate-us-east-2"
}
