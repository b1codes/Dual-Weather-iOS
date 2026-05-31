import Foundation

// Update these values after Plan 2 (Terraform) is applied.
// auth0Audience must match the API identifier in Auth0 dashboard exactly.
// apiBaseURL comes from `terraform output -raw api_url` in infra/runtime/.
enum AppConfig {
    static let auth0Audience = "https://api.dualweather/"
    static let apiBaseURL    = URL(string: "https://placeholder.execute-api.us-east-2.amazonaws.com")!
}
