//
//  WeatherDetailsView.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 1/26/25.
//

import SwiftUI
import CoreLocation
import WeatherKit

struct WeatherDetailsView: View {
    @AppStorage("backgroundTheme") private var backgroundTheme = 0 // 0: Default, 1: Dynamic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var locationName: String
    private var coordinate: CLLocationCoordinate2D?
    @StateObject private var weatherViewModel = WeatherViewModel()

    /// `coordinate`, when the caller already has one (current-location GPS fix,
    /// or a saved location's stored lat/lon), skips `fetchCoordinates(from:)` —
    /// forward-geocoding a place name back into coordinates the caller already
    /// had is a wasted network round trip, and risks landing in a different
    /// `WeatherCache` bucket than the original fix, turning what should be a
    /// cache hit into a second real WeatherKit request.
    init(locationName: String, coordinate: CLLocationCoordinate2D? = nil) {
        self.locationName = locationName
        self.coordinate = coordinate
    }

    private var isDynamic: Bool { backgroundTheme == 1 }

    var dynamicBackground: some View {
        Group {
            if isDynamic, let condition = weatherViewModel.currentWeather?.currentWeather.condition {
                let colors = weatherBackgroundColors[condition] ?? [Color(red: 0.0, green: 0.28, blue: 0.82), Color(red: 0.0, green: 0.58, blue: 1.0), Color(red: 0.38, green: 0.82, blue: 1.0)]
                LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            } else {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
            }
        }
    }

    // Some dynamic backgrounds resolve to near-white in their bottom-trailing stop
    // (e.g. snow conditions), which drops white text below 2:1 contrast. This scrim
    // guarantees ~4.5:1+ for the header text regardless of which condition is live.
    private var dynamicTextScrim: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .black.opacity(0.62), location: 0.0),
                .init(color: .black.opacity(0.30), location: 0.32),
                .init(color: .clear, location: 0.6)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    var body: some View {
        ZStack {
            dynamicBackground
            if isDynamic {
                dynamicTextScrim
            }

            VStack(spacing: 20) {
                if let currentWeather = weatherViewModel.currentWeather {
                    let condition = currentWeather.currentWeather.condition
                    let accentColor = weatherConditionAccentColors[condition] ?? .accentColor

                    Text(locationName)
                        .font(AppFont.display())
                        .foregroundStyle(isDynamic ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    let iconName = weatherConditionsDictionary[condition]?[currentWeather.currentWeather.isDaylight] ?? "questionmark.circle"
                    Group {
                        if reduceMotion {
                            Image(systemName: iconName)
                                .resizable()
                        } else {
                            Image(systemName: iconName)
                                .resizable()
                                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                        }
                    }
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 130)
                    .foregroundStyle(accentColor)
                    .accessibilityHidden(true)

                    Text(condition.description)
                        .font(AppFont.title())
                        .foregroundStyle(isDynamic ? AnyShapeStyle(.white.opacity(0.88)) : AnyShapeStyle(.secondary))

                    // Glass stats panel. `.glassCard()` handles the iOS 26 vs. earlier
                    // split internally, so this always renders — the app's core dual-unit
                    // data must never silently disappear on older OS versions.
                    VStack(spacing: 0) {
                        WeatherStatRow(
                            label: "Temperature",
                            leftValue: "\(Int(currentWeather.currentWeather.temperature.value.rounded()))°C",
                            rightValue: "\(Int(currentWeather.currentWeather.temperature.converted(to: .fahrenheit).value.rounded()))°F"
                        )
                        Divider().padding(.horizontal, 16)
                        WeatherStatRow(
                            label: "Feels Like",
                            leftValue: "\(Int(currentWeather.currentWeather.apparentTemperature.value.rounded()))°C",
                            rightValue: "\(Int(currentWeather.currentWeather.apparentTemperature.converted(to: .fahrenheit).value.rounded()))°F"
                        )
                        Divider().padding(.horizontal, 16)
                        WeatherStatRow(
                            label: "Wind",
                            leftValue: "\(Int(currentWeather.currentWeather.wind.speed.value.rounded())) km/h",
                            rightValue: "\(Int(currentWeather.currentWeather.wind.speed.converted(to: .milesPerHour).value.rounded())) mph"
                        )
                        Divider().padding(.horizontal, 16)
                        HStack {
                            Label("Humidity", systemImage: "humidity")
                                .foregroundStyle(accentColor)
                                .font(AppFont.headline())
                            Spacer()
                            Text(currentWeather.currentWeather.humidity.formatted(.percent))
                                .font(AppFont.body())
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .accessibilityElement(children: .combine)
                        Divider().padding(.horizontal, 16)
                        HStack {
                            Label("UV Index", systemImage: "sun.max")
                                .foregroundStyle(accentColor)
                                .font(AppFont.headline())
                            Spacer()
                            Text("\(currentWeather.currentWeather.uvIndex.value)")
                                .font(AppFont.body())
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .accessibilityElement(children: .combine)
                    }
                    .glassSurface(cornerRadius: Radius.large)
                    .padding(.horizontal, Spacing.medium)

                } else if let error = weatherViewModel.locationError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(.top, 60)
                    Text("Fetching weather for \(locationName)...")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            fetchWeatherForLocation()
        }
        .onChange(of: coordinate.map { "\($0.latitude),\($0.longitude)" }) { _, _ in
            guard let coordinate else { return }
            Task {
                await weatherViewModel.fetchWeather(for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            }
        }
    }

    private func fetchWeatherForLocation() {
        if let coordinate {
            Task {
                await weatherViewModel.fetchWeather(for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            }
            return
        }
        weatherViewModel.fetchCoordinates(from: locationName) { result in
            switch result {
            case .success(let location):
                Task {
                    await weatherViewModel.fetchWeather(for: location)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    weatherViewModel.locationError = "Failed to get coordinates: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct WeatherStatRow: View {
    let label: String
    let leftValue: String
    let rightValue: String

    var body: some View {
        HStack {
            Text(leftValue)
                .font(AppFont.body())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label)
                .font(AppFont.headline())
                .frame(maxWidth: .infinity, alignment: .center)
            Text(rightValue)
                .font(AppFont.body())
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(leftValue), \(rightValue)")
    }
}

#Preview {
    WeatherDetailsView(locationName: "San Francisco")
}
