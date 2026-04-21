//
//  WeatherService.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 2/2/25.
//

@preconcurrency import WeatherKit
import CoreLocation

actor WeatherCache {
    static let shared = WeatherCache()
    private init() {}

    private struct Entry {
        let weather: Weather
        let fetchedAt: Date
    }

    private var cache: [String: Entry] = [:]
    private let ttl: TimeInterval = 600 // 10 minutes

    func get(for location: CLLocation) -> Weather? {
        let key = cacheKey(for: location)
        guard let entry = cache[key], Date().timeIntervalSince(entry.fetchedAt) < ttl else {
            return nil
        }
        return entry.weather
    }

    func set(_ weather: Weather, for location: CLLocation) {
        if cache.count >= 100 {
            cache = cache.filter { Date().timeIntervalSince($0.value.fetchedAt) < ttl }
        }
        cache[cacheKey(for: location)] = Entry(weather: weather, fetchedAt: Date())
    }

    func invalidate(for location: CLLocation) {
        cache.removeValue(forKey: cacheKey(for: location))
    }

    // 2 decimal places ≈ 1.1 km latitude grid; longitude bucket shrinks at high latitudes
    private func cacheKey(for location: CLLocation) -> String {
        let lat = (location.coordinate.latitude * 100).rounded() / 100
        let lon = (location.coordinate.longitude * 100).rounded() / 100
        return "\(lat),\(lon)"
    }
}

class WeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentWeather: Weather?
    @Published var currentLocation: String?
    @Published var locationError: String?
    @Published var isLocationAccessGranted: Bool = false

    private let weatherService = WeatherService()
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var pendingForceRefresh = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation(forceRefresh: Bool = false) {
        pendingForceRefresh = forceRefresh
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestWhenInUseAuthorization()
        } else {
            DispatchQueue.main.async {
                self.locationError = "Location services are disabled."
            }
        }
    }

    // Fetch CLLocation from location name
    func fetchCoordinates(from address: String, completion: @escaping (Result<CLLocation, Error>) -> Void) {
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let placemark = placemarks?.first, let location = placemark.location {
                completion(.success(location))
            } else {
                completion(.failure(NSError(domain: "GeocodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Location not found"])))
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.startUpdatingLocation()
            case .denied, .restricted:
                self.locationError = "Location access denied. Please enable location access in Settings."
            case .notDetermined:
                self.locationError = "Location permission is required to fetch weather."
            @unknown default:
                self.locationError = "Unknown location authorization status."
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let forceRefresh = pendingForceRefresh
            pendingForceRefresh = false
            Task {
                await fetchWeather(for: location, forceRefresh: forceRefresh)
                await fetchLocationName(for: location)
            }
            locationManager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "Failed to find location: \(error.localizedDescription)"
    }

    // Used by pull-to-refresh: awaitable so the spinner stays alive until data arrives
    func refreshCurrentWeather() async {
        guard let last = locationManager.location else { return }
        await fetchWeather(for: last, forceRefresh: true)
        await fetchLocationName(for: last)
    }

    func fetchWeather(for location: CLLocation, forceRefresh: Bool = false) async {
        if !forceRefresh, let cached = await WeatherCache.shared.get(for: location) {
            await MainActor.run {
                self.currentWeather = cached
            }
            return
        }
        do {
            let weather = try await weatherService.weather(for: location)
            await WeatherCache.shared.set(weather, for: location)
            await MainActor.run {
                self.currentWeather = weather
            }
        } catch {
            await MainActor.run {
                self.locationError = "Failed to fetch weather: \(error.localizedDescription)"
            }
        }
    }

    func fetchLocationName(for location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let locationName = [placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                await MainActor.run {
                    self.currentLocation = locationName
                }
            }
        } catch {
            await MainActor.run {
                self.locationError = "Failed to fetch location name: \(error.localizedDescription)"
            }
        }
    }
}
