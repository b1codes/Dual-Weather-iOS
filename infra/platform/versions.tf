terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.5"
    }
  }
}
