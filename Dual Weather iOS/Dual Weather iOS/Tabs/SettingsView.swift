//
//  SettingsView.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 1/26/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("useEmoji") private var useEmoji = false
    @AppStorage("backgroundTheme") private var backgroundTheme = 0 // 0: Default, 1: Dynamic

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
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
