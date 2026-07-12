import SwiftUI
import MapKit

struct SavedLocationsView: View {
    @State private var locations: [SavedLocation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var deleteErrorMessage: String?
    @State private var isEditing = false

    var body: some View {
        NavigationView {
            VStack {
                LocationsGrid(
                    locations: $locations,
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    isEditing: isEditing,
                    deleteAction: deleteLocation
                )
            }
            .navigationTitle("Saved Locations")
            .navigationBarTitleDisplayMode(.automatic)
            .task { await fetchLocations() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isEditing.toggle() }) {
                        Text(isEditing ? "Done" : "Edit")
                            .fontWeight(.bold)
                    }
                }
            }
            .alert("Delete Failed", isPresented: .init(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { deleteErrorMessage = nil }
            } message: {
                Text(deleteErrorMessage ?? "")
            }
        }
    }

    private func fetchLocations() async {
        isLoading = true
        errorMessage = nil
        do {
            locations = try await LocationsRepository.shared.fetchLocations()
        } catch {
            errorMessage = "Failed to fetch locations: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func deleteLocation(_ location: SavedLocation) {
        Task {
            do {
                try await LocationsRepository.shared.deleteLocation(id: location.id)
                locations.removeAll { $0.id == location.id }
            } catch {
                deleteErrorMessage = "Failed to delete \(location.city): \(error.localizedDescription)"
            }
        }
    }
}

struct LocationsGrid: View {
    @Binding var locations: [SavedLocation]
    let isLoading: Bool
    let errorMessage: String?
    let isEditing: Bool
    let deleteAction: (SavedLocation) -> Void

    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading locations...").padding()
            } else if let errorMessage {
                Text(errorMessage).foregroundColor(.red).padding()
            } else if locations.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 30) {
                    ForEach(locations) { location in
                        NavigationLink(destination: WeatherDetailsView(
                            locationName: location.locationString(),
                            coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                        )) {
                            LocationCard(location: location)
                                .overlay(
                                    ZStack {
                                        if isEditing {
                                            Color.black.opacity(0.18)
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                                .frame(width: 150, height: 200)

                                            DeleteButton(location: location, deleteAction: deleteAction)
                                                .padding(8)
                                        }
                                    }
                                )
                                .frame(width: 150, height: 200)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Saved Locations")
                .font(AppFont.headline())
            Text("Search for a city and tap Save to keep it here.")
                .font(AppFont.label())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 80)
        .accessibilityElement(children: .combine)
    }
}

struct DeleteButton: View {
    let location: SavedLocation
    let deleteAction: (SavedLocation) -> Void
    @State private var showsConfirmation = false

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: { showsConfirmation = true }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass(.regular.tint(.red)))
            } else {
                Button(action: { showsConfirmation = true }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .accessibilityLabel("Delete \(location.city)")
        .confirmationDialog(
            "Delete \(location.city)?",
            isPresented: $showsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteAction(location) }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    SavedLocationsView()
}
