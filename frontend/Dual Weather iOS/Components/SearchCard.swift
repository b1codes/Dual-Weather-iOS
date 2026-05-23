//
//  SearchCard.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 2/3/25.
//

import SwiftUI
import MapKit
import FirebaseFirestore

struct SearchCard: View {
    var location: Location
    @State private var coordinate: CLLocationCoordinate2D? // To store fetched coordinates
    @State private var errorMessage: String? // To handle errors
    @State private var isSaving: Bool = false // Loading state for Firestore operation
    @State private var isAlreadySaved: Bool = false // Track if the location is already saved

    let maxHeight: CGFloat = 100
    let maxWidth: CGFloat = 600

    let database = Firestore.firestore() // Firestore instance

    var body: some View {
        HStack {
            if let coordinate = coordinate {
                MapThumbnailView(coordinate: coordinate, size: CGSize(width: 80, height: 80)).padding(.all, 10)
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            } else {
                ProgressView("Loading...")
                    .frame(width: 130, height: 130) // Placeholder while loading coordinates
            }

            Text(location.locationString())
                .lineLimit(1)
            Spacer()
            if #available(iOS 26.0, *) {
                Button(action: addToFirestore) {
                    Image(systemName: isSaving || isAlreadySaved ? "checkmark" : "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(isAlreadySaved ? .green : .blue)
                        .padding(8)
                }
                .buttonStyle(.glass)
                .disabled(isSaving || isAlreadySaved)
            } else {
                // Fallback on earlier versions
            }

        }
        .padding()
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .onAppear {
            if let lat = location.latitude, let lon = location.longitude {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            } else {
                fetchCoordinates()
            }
            checkIfLocationIsSaved()
        }
    }

    private func fetchCoordinates() {
        LocationService.shared.getCoordinates(forCity: location.city, state: location.state) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedCoordinate):
                    coordinate = fetchedCoordinate
                    errorMessage = nil
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func checkIfLocationIsSaved() {
        database.collection("locations")
            .whereField("city", isEqualTo: location.city)
            .whereField("state", isEqualTo: location.state)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        errorMessage = error.localizedDescription
                    } else if let snapshot = snapshot, !snapshot.documents.isEmpty {
                        isAlreadySaved = true
                    }
                }
            }
    }

    private func addToFirestore() {
        guard let coordinate = coordinate else { return }

        let locationData: [String: Any] = [
            "city": location.city,
            "state": location.state,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ]

        isSaving = true

        database.collection("locations").addDocument(data: locationData) { error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    SearchCard(location: Location(city: "West Lafayette", state: "Indiana"))
}
