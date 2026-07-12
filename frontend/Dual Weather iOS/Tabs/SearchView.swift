//
//  SearchView.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 2/3/25.
//

import SwiftUI

func savedLocationKey(city: String, state: String) -> String {
    "\(city)|\(state)"
}

struct SearchView: View {
    @State private var results = [Location]()
    @State private var savedLocationKeys: Set<String> = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var hasSearched = false
    @FocusState private var isTextFieldFocused: Bool // Focus management for TextField

    @MainActor
    func startSearch() async {
        guard !self.searchText.isEmpty else { return }

        self.isLoading = true
        self.results = [] // Clear previous results
        self.isTextFieldFocused = false // Dismiss keyboard

        // Search results and the saved-locations lookup are independent — fetch
        // both concurrently once here, instead of each result card fetching the
        // full saved-locations list on its own (N+1).
        async let searchResults = performSearch()
        async let savedKeys = fetchSavedLocationKeys()
        let (results, keys) = await (searchResults, savedKeys)

        self.results = results
        self.savedLocationKeys = keys
        self.hasSearched = true

        self.isLoading = false // Stop loading
    }

    func resetSearch() {
        // Reset all states explicitly
        searchText = ""
        results = []
        isLoading = false
        hasSearched = false
        isTextFieldFocused = false // Clear keyboard focus
    }

    func performSearch() async -> [Location] {
        await LocationService.shared.searchLocations(for: searchText)
    }

    func fetchSavedLocationKeys() async -> Set<String> {
        guard let saved = try? await LocationsRepository.shared.fetchLocations() else { return [] }
        return Set(saved.map { savedLocationKey(city: $0.city, state: $0.state) })
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    HStack {
                        TextField("Search for a City", text: $searchText)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                Task { await startSearch() }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .glassSurface(cornerRadius: Radius.small)
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
                    } else if hasSearched && results.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No matches for \"\(searchText)\"")
                                .font(AppFont.label())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                        .accessibilityElement(children: .combine)
                    }

                    LazyVStack {
                        ForEach(results, id: \.self) { result in
                            SearchCard(
                                location: result,
                                isInitiallySaved: savedLocationKeys.contains(
                                    savedLocationKey(city: result.city, state: result.state)
                                )
                            )
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
