variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-2"
}

variable "auth0_domain" {
  description = "Auth0 tenant domain, e.g. example.us.auth0.com"
  type        = string
}

variable "auth0_client_id" {
  description = "Auth0 Management API M2M client_id used by the Terraform provider."
  type        = string
  sensitive   = true
}

variable "auth0_client_secret" {
  description = "Auth0 Management API M2M client_secret used by the Terraform provider."
  type        = string
  sensitive   = true
}

variable "auth0_audience" {
  description = "Identifier (audience) for the Dual Weather API resource server."
  type        = string
  default     = "https://api.dualweather/"
}

variable "ios_bundle_id" {
  description = "iOS app bundle identifier — used as the custom URL scheme for Auth0 callbacks."
  type        = string
}
