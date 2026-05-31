terraform {
  backend "s3" {
    bucket         = "dual-weather-tfstate-us-east-2"
    key            = "runtime/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "dual-weather-tflock"
    encrypt        = true
  }
}
