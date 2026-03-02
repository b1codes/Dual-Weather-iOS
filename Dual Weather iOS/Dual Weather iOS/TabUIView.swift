//
//  TabUIView.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 1/26/25.
//

import SwiftUI

struct TabUIView: View {

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .navigationTitle("Home")
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .navigationTitle("Search")
            SavedLocationsView()
                .tabItem {
                    Image(systemName: "bookmark.fill")
                    Text("Saved")
                }
                .navigationTitle("Saved")
            ConvertView()
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Convert")
                }
                .navigationTitle("Convert")
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .navigationTitle("Settings")
        }
    }
}

#Preview {
    TabUIView()
}
