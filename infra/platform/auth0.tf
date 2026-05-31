resource "auth0_resource_server" "api" {
  name        = "Dual Weather API"
  identifier  = var.auth0_audience
  signing_alg = "RS256"

  token_lifetime                                  = 86400
  skip_consent_for_verifiable_first_party_clients = true
}

resource "auth0_client" "ios_app" {
  name        = "Dual Weather iOS"
  description = "Native iOS app for Dual Weather"
  app_type    = "native"

  is_first_party  = true
  oidc_conformant = true

  grant_types = [
    "authorization_code",
    "refresh_token",
  ]

  callbacks = [
    "${var.ios_bundle_id}://${var.auth0_domain}/ios/${var.ios_bundle_id}/callback",
  ]

  allowed_logout_urls = [
    "${var.ios_bundle_id}://${var.auth0_domain}/ios/${var.ios_bundle_id}/callback",
  ]

  refresh_token {
    rotation_type   = "rotating"
    expiration_type = "expiring"
    leeway          = 0
    token_lifetime  = 2592000
  }

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_connection" "database" {
  name     = "Username-Password-Authentication"
  strategy = "auth0"

  options {
    password_policy = "good"

    password_complexity_options {
      min_length = 8
    }

    brute_force_protection = true
    disable_signup         = false

    enabled_database_customization = false
  }

  lifecycle {
    ignore_changes = [options]
  }
}

resource "auth0_connection_clients" "database_to_ios" {
  connection_id = auth0_connection.database.id
  enabled_clients = [
    auth0_client.ios_app.id,
  ]
}

resource "auth0_client_grant" "ios_to_api" {
  client_id = auth0_client.ios_app.id
  audience  = auth0_resource_server.api.identifier

  scopes = []
}
