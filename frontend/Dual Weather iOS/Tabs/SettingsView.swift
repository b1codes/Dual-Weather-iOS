import SwiftUI

struct SettingsView: View {
    @AppStorage("useEmoji") private var useEmoji = false
    @AppStorage("backgroundTheme") private var backgroundTheme = 0
    @EnvironmentObject var session: AuthSession

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Visuals")) {
                    Toggle("Use Emojis for Icons", isOn: $useEmoji)

                    Picker("Background Theme", selection: $backgroundTheme) {
                        Text("Default").tag(0)
                        Text("Dynamic Weather").tag(1)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        Task { await session.logout() }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthSession())
}
