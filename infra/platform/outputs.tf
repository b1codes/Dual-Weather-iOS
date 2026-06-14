output "auth0_domain" {
  description = "Auth0 tenant domain (no scheme, no trailing slash)."
  value       = var.auth0_domain
}

output "auth0_native_client_id" {
  description = "client_id of the Native iOS Auth0 application."
  value       = auth0_client.ios_app.client_id
}

output "auth0_audience" {
  description = "API audience identifier."
  value       = auth0_resource_server.api.identifier
}

output "auth0_issuer" {
  description = "JWT issuer URL — used as the JWT authorizer's issuer URL."
  value       = "https://${var.auth0_domain}/"
}

output "test_m2m_client_id" {
  description = "client_id for the test M2M application."
  value       = auth0_client.test_m2m.client_id
}
