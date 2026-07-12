import SwiftUI

struct SettingsView: View {
    @AppStorage("backgroundTheme") private var backgroundTheme = 0
    @EnvironmentObject var session: AuthSession
    @State private var showsSignOutConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Visuals")) {
                    Picker("Background Theme", selection: $backgroundTheme) {
                        Text("Default").tag(0)
                        Text("Dynamic Weather").tag(1)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showsSignOutConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Sign out of Dual Weather?",
                isPresented: $showsSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await session.logout() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthSession())
}
