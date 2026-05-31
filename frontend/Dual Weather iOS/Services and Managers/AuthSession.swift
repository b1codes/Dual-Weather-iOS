import Auth0
import Foundation

@MainActor
final class AuthSession: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true

    private var credentialsManager = CredentialsManager(authentication: Auth0.authentication())

    func checkSession() async {
        guard credentialsManager.canRenew() else {
            isLoading = false
            return
        }
        do {
            _ = try await credentialsManager.credentials(minTTL: 60)
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
        isLoading = false
    }

    func login() async {
        do {
            let credentials = try await Auth0
                .webAuth()
                .audience(AppConfig.auth0Audience)
                .scope("openid profile email offline_access")
                .start()
            _ = credentialsManager.store(credentials: credentials)
            isAuthenticated = true
        } catch {
            // User cancelled or network error — stay on login screen.
        }
    }

    func logout() async {
        do {
            try await Auth0.webAuth().clearSession()
        } catch {
            // Clear local credentials even if the remote session clear fails.
        }
        _ = credentialsManager.clear()
        isAuthenticated = false
    }

    func accessToken() async throws -> String {
        let credentials = try await credentialsManager.credentials(minTTL: 60)
        return credentials.accessToken
    }
}
