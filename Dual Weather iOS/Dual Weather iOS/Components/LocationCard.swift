//
//  LocationCard.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 2/2/25.
//

import SwiftUI
import MapKit

struct LocationCard: View {
    var location: Location
    @State private var coordinate: CLLocationCoordinate2D? // To store fetched coordinates
    @State private var errorMessage: String? // To handle errors

    let maxHeight: CGFloat = 200
    let maxWidth: CGFloat = 150

    var body: some View {
        VStack {
            Text(location.city)
                .font(.subheadline)
                .lineLimit(1)
                .padding([.top, .bottom], 10)
            if let coordinate = coordinate {
                MapThumbnailView(coordinate: coordinate, size: CGSize(width: 130, height: 130))
            } else if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            } else {
                ProgressView("Loading...")
                    .frame(width: 130, height: 130) // Placeholder while loading coordinates
            }
        }
        .padding()
        .frame(width: maxWidth, height: maxHeight)
        .onAppear {
            if let lat = location.latitude, let lon = location.longitude {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            } else {
                fetchCoordinates()
            }
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
}

#Preview {
    LocationCard(location: Location(city: "West Lafayette", state: "Indiana"))
}
