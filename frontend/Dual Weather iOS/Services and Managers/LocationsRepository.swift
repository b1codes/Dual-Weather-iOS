import Foundation

struct SavedLocation: Codable, Hashable, Identifiable {
    let id: String
    let city: String
    let state: String
    let latitude: Double
    let longitude: Double
    let createdAt: String

    func locationString() -> String {
        "\(city), \(stateToAbbreviation(state) ?? state)"
    }
}

private struct CreateLocationPayload: Encodable {
    let city: String
    let state: String
    let latitude: Double
    let longitude: Double
}

final class LocationsRepository {
    static let shared = LocationsRepository()
    private let client = APIClient.shared

    private init() {}

    func fetchLocations() async throws -> [SavedLocation] {
        try await client.get("/locations")
    }

    func saveLocation(city: String, state: String, latitude: Double, longitude: Double) async throws -> SavedLocation {
        let payload = CreateLocationPayload(city: city, state: state, latitude: latitude, longitude: longitude)
        return try await client.post("/locations", body: payload)
    }

    func deleteLocation(id: String) async throws {
        try await client.delete("/locations/\(id)")
    }
}
