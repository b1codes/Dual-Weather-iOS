import SwiftUI
import MapKit

struct LocationCard: View {
    var location: SavedLocation

    let maxHeight: CGFloat = 200
    let maxWidth: CGFloat = 150

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    var body: some View {
        VStack {
            Text(location.city)
                .font(.subheadline)
                .lineLimit(1)
                .padding([.top, .bottom], 10)
            MapThumbnailView(coordinate: coordinate, size: CGSize(width: 130, height: 130))
        }
        .padding()
        .frame(width: maxWidth, height: maxHeight)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    LocationCard(location: SavedLocation(
        id: "preview",
        city: "West Lafayette",
        state: "Indiana",
        latitude: 40.427,
        longitude: -86.916,
        createdAt: ""
    ))
}
