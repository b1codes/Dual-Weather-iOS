data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "platform/terraform.tfstate"
    region = var.region
  }
}

data "aws_caller_identity" "current" {}
