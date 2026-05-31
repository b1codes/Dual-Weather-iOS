import SwiftUI

@main
struct Dual_Weather_iOSApp: App {
    @StateObject private var authSession = AuthSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authSession)
                .task {
                    APIClient.shared.tokenProvider = { [weak authSession] in
                        guard let session = authSession else { throw APIError.badURL }
                        return try await session.accessToken()
                    }
                    await authSession.checkSession()
                }
        }
    }
}
