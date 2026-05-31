provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "dual-weather"
      Component = "runtime"
      ManagedBy = "terraform"
    }
  }
}
