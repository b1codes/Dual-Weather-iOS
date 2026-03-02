//
//  SavedLocationsView.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 1/26/25.
//

import SwiftUI
import FirebaseFirestore
import MapKit

struct SavedLocationsView: View {
    @State private var locations: [Location] = [] // Array to store fetched locations
    @State private var isLoading = true           // Loading state
    @State private var errorMessage: String?      // Error message state
    @State private var isEditing = false          // Edit mode toggle

    let database = Firestore.firestore() // Firestore instance

    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationView {
            VStack {
                LocationsGrid(locations: $locations, isLoading: isLoading, errorMessage: errorMessage, isEditing: isEditing, deleteAction: deleteLocation)
            }
            .navigationTitle("Saved Locations")
            .navigationBarTitleDisplayMode(.automatic)
            .onAppear {
                fetchLocations()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isEditing.toggle() }) {
                        Text(isEditing ? "Done" : "Edit")
                            .fontWeight(.bold)
                    }
                }
            }
        }
    }

    // Fetch locations from Firestore
    private func fetchLocations() {
        isLoading = true
        errorMessage = nil

        DatabaseManager.shared.fetchLocations { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fetchedLocations):
                    locations = fetchedLocations
                case .failure(let error):
                    errorMessage = "Failed to fetch locations: \(error.localizedDescription)"
                }
            }
        }
    }

    // Delete location from Firestore
    private func deleteLocation(_ location: Location) {
        let query = database.collection("locations")
            .whereField("city", isEqualTo: location.city)
            .whereField("state", isEqualTo: location.state)

        query.getDocuments { snapshot, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Failed to delete: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    self.errorMessage = "Location not found in Firestore."
                    return
                }

                for document in documents {
                    self.deleteDocument(documentID: document.documentID, location: location)
                }
            }
        }
    }

    // Separate function to delete Firestore document
    private func deleteDocument(documentID: String, location: Location) {
        database.collection("locations").document(documentID).delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Failed to delete: \(error.localizedDescription)"
                } else {
                    self.locations.removeAll { $0.city == location.city && $0.state == location.state }
                }
            }
        }
    }

}

struct LocationsGrid: View {
    @Binding var locations: [Location]
    let isLoading: Bool
    let errorMessage: String?
    let isEditing: Bool
    let deleteAction: (Location) -> Void

    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading locations...").padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red).padding()
            } else {
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(locations, id: \.city) { location in
                        NavigationLink(destination: WeatherDetailsView(locationName: location.locationString())) {

                            LocationCard(location: location)
                                .overlay(
                                    ZStack {
                                        if isEditing {
                                            Color.white.opacity(0.3) // Slight opacity for better contrast
                                                .background(.ultraThinMaterial) // iOS blur effect
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .frame(width: 150, height: 200)

                                            DeleteButton(location: location, deleteAction: deleteAction)
                                                .padding(8)
                                        }
                                    }
                                )
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 3)
                                .frame(width: 150, height: 200)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }
}

struct DeleteButton: View {
    let location: Location
    let deleteAction: (Location) -> Void

    var body: some View {
        Button(action: { deleteAction(location) }) {
            Image(systemName: "trash")
                .foregroundColor(.red)
                .padding(8)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(radius: 3)
        }
    }
}

#Preview {
    SavedLocationsView()
}
