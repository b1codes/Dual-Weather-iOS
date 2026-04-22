//
//  SearchView.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 2/3/25.
//

import SwiftUI

struct SearchView: View {
    @State private var results = [Location]()
    @State private var searchText: String = ""
    @State private var isLoading = false
    @FocusState private var isTextFieldFocused: Bool // Focus management for TextField

    @MainActor
    func startSearch() async {
        guard !self.searchText.isEmpty else { return }

        self.isLoading = true
        self.results = [] // Clear previous results
        self.isTextFieldFocused = false // Dismiss keyboard

        // Perform search and handle results
        let results: [Location] = await performSearch()

        self.results = results // Update results

        self.isLoading = false // Stop loading
        print("done searching!")
    }

    func resetSearch() {
        // Reset all states explicitly
        searchText = ""
        results = []
        isLoading = false
        isTextFieldFocused = false // Clear keyboard focus
    }

    func performSearch() async -> [Location] {
        self.isLoading = true
        defer { self.isLoading = false }

        return await LocationService.shared.searchLocations(for: searchText)

    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    HStack {
                        TextField("Search for a City", text: $searchText)
                            .focused($isTextFieldFocused)
                            .onChange(of: searchText) {
                                print("Search text changed to: \(searchText)")
                            }
                            .onSubmit {
                                Task { await startSearch() }
                            }
                            .padding(7)
                            .padding(.horizontal, 25)
                            .background(Color(.systemGray4))
                            .cornerRadius(8)
                            .padding(.horizontal, 10)

                        if !searchText.isEmpty {
                            Button("Cancel") {
                                resetSearch()
                            }
                            .foregroundColor(.blue)
                            .padding(.trailing, 10)
                        }
                    }
                    if isLoading {
                        ProgressView("Searching...").padding()
                    }

                    LazyVStack {
                        ForEach(results, id: \.self) { result in
                            SearchCard(location: result)
                        }
                    }
                }
            }
            .onTapGesture { isTextFieldFocused = false }
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchView()
}
