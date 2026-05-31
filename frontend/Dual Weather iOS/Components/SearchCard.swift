import SwiftUI
import MapKit

struct SearchCard: View {
    var location: Location
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var coordError: String?
    @State private var isSaving = false
    @State private var savedId: String?
    @State private var saveErrorMessage: String?

    private var isAlreadySaved: Bool { savedId != nil }

    let maxHeight: CGFloat = 100
    let maxWidth: CGFloat = 600

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
                .lineLimit(1)
            Spacer()
            saveButton
        }
        .padding()
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .task {
            async let coord: () = resolveCoordinate()
            async let saved: () = checkIfAlreadySaved()
            _ = await (coord, saved)
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
                    .foregroundStyle(isAlreadySaved ? .green : .blue)
                    .padding(8)
            }
            .buttonStyle(.glass)
            .disabled(isSaving || isAlreadySaved || coordinate == nil)
        } else {
            Button(action: saveLocation) {
                Image(systemName: isSaving || isAlreadySaved ? "checkmark" : "plus")
                    .fontWeight(.semibold)
                    .foregroundStyle(isAlreadySaved ? .green : .blue)
                    .padding(8)
            }
            .buttonStyle(.bordered)
            .disabled(isSaving || isAlreadySaved || coordinate == nil)
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

    private func checkIfAlreadySaved() async {
        do {
            let saved = try await LocationsRepository.shared.fetchLocations()
            savedId = saved.first(where: { $0.city == location.city && $0.state == location.state })?.id
        } catch {
            // Silent fail — show card as unsaved; user can try saving normally.
        }
    }

    private func saveLocation() {
        guard let coordinate, !isSaving, !isAlreadySaved else { return }
        isSaving = true
        Task {
            do {
                let saved = try await LocationsRepository.shared.saveLocation(
                    city: location.city,
                    state: location.state,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                savedId = saved.id
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
