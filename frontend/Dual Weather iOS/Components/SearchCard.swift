import SwiftUI
import MapKit

struct SearchCard: View {
    var location: Location
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var coordError: String?
    @State private var isSaving = false
    @State private var isAlreadySaved: Bool
    @State private var saveErrorMessage: String?

    let maxHeight: CGFloat = 100
    let maxWidth: CGFloat = 600

    /// `isInitiallySaved` is looked up once by the parent search list (one shared
    /// fetch of saved locations) rather than each card re-fetching independently —
    /// avoids an N+1 network call per search result.
    init(location: Location, isInitiallySaved: Bool = false) {
        self.location = location
        _isAlreadySaved = State(initialValue: isInitiallySaved)
    }

    var body: some View {
        HStack {
            if let coordinate {
                MapThumbnailView(coordinate: coordinate, size: CGSize(width: 80, height: 80))
                    .padding(.all, 10)
            } else if let coordError {
                Text("Error: \(coordError)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            } else {
                ProgressView("Loading...")
                    .frame(width: 130, height: 130)
            }

            Text(location.locationString())
                .font(AppFont.body())
                .lineLimit(1)
            Spacer()
            saveButton
        }
        .padding()
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .glassSurface(cornerRadius: Radius.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .task {
            await resolveCoordinate()
        }
        .alert("Save Failed", isPresented: .init(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var saveButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: saveLocation) {
                Image(systemName: isSaving || isAlreadySaved ? "checkmark" : "plus")
                    .fontWeight(.semibold)
                    .foregroundStyle(isAlreadySaved ? .green : .primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .disabled(isSaving || isAlreadySaved || coordinate == nil)
            .accessibilityLabel(isAlreadySaved ? "Location saved" : "Save location")
        } else {
            Button(action: saveLocation) {
                Image(systemName: isSaving || isAlreadySaved ? "checkmark" : "plus")
                    .fontWeight(.semibold)
                    .foregroundStyle(isAlreadySaved ? .green : .primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(isSaving || isAlreadySaved || coordinate == nil)
            .accessibilityLabel(isAlreadySaved ? "Location saved" : "Save location")
        }
    }

    private func resolveCoordinate() async {
        if let lat = location.latitude, let lon = location.longitude {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            return
        }
        await withCheckedContinuation { continuation in
            LocationService.shared.getCoordinates(forCity: location.city, state: location.state) { result in
                switch result {
                case .success(let coord):
                    DispatchQueue.main.async { self.coordinate = coord }
                case .failure(let error):
                    DispatchQueue.main.async { self.coordError = error.localizedDescription }
                }
                continuation.resume()
            }
        }
    }

    private func saveLocation() {
        guard let coordinate, !isSaving, !isAlreadySaved else { return }
        isSaving = true
        Task {
            do {
                _ = try await LocationsRepository.shared.saveLocation(
                    city: location.city,
                    state: location.state,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                isAlreadySaved = true
            } catch {
                saveErrorMessage = "Could not save \(location.city): \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}

#Preview {
    SearchCard(location: Location(city: "West Lafayette", state: "Indiana"))
}
