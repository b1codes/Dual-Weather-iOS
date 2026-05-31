import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: AuthSession

    var body: some View {
        if session.isLoading {
            ProgressView()
                .scaleEffect(1.5)
        } else if session.isAuthenticated {
            TabUIView()
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthSession())
}
