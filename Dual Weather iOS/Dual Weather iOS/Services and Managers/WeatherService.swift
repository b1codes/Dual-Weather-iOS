//
//  WeatherService.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 2/2/25.
//

@preconcurrency import WeatherKit
import CoreLocation

class WeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentWeather: Weather?
    @Published var currentLocation: String?
    @Published var locationError: String?
    @Published var isLocationAccessGranted: Bool = false

    private let weatherService = WeatherService()
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
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
            Task {
                await fetchWeather(for: location)
                await fetchLocationName(for: location)
            }
            locationManager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "Failed to find location: \(error.localizedDescription)"
    }

    func fetchWeather(for location: CLLocation) async {
        do {
            let weather = try await weatherService.weather(for: location)
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
