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
    @AppStorage("useEmoji") private var useEmoji = false
    @AppStorage("backgroundTheme") private var backgroundTheme = 0 // 0: Default, 1: Dynamic

    private var locationName: String
    @StateObject private var weatherViewModel = WeatherViewModel()

    init(locationName: String) {
        self.locationName = locationName
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

    var body: some View {
        ZStack {
            dynamicBackground

            VStack(spacing: 20) {
                if let currentWeather = weatherViewModel.currentWeather {
                    let condition = currentWeather.currentWeather.condition
                    let accentColor = weatherConditionAccentColors[condition] ?? .accentColor

                    Text(locationName)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundStyle(isDynamic ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    if useEmoji {
                        Text(weatherEmojiDictionary[condition] ?? "❓")
                            .font(.system(size: 110))
                    } else {
                        let iconName = weatherConditionsDictionary[condition]?[currentWeather.currentWeather.isDaylight] ?? "questionmark.circle"
                        Image(systemName: iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 130)
                            .foregroundStyle(accentColor)
                            .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                    }

                    Text(condition.description)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(isDynamic ? AnyShapeStyle(.white.opacity(0.88)) : AnyShapeStyle(.secondary))

                    // Glass stats panel
                    if #available(iOS 26.0, *) {
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
                                    .font(.headline)
                                Spacer()
                                Text(currentWeather.currentWeather.humidity.formatted(.percent))
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            Divider().padding(.horizontal, 16)
                            HStack {
                                Label("UV Index", systemImage: "sun.max")
                                    .foregroundStyle(accentColor)
                                    .font(.headline)
                                Spacer()
                                Text("\(currentWeather.currentWeather.uvIndex.value)")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .glassEffect(in: .rect(cornerRadius: 20))
                        .padding(.horizontal, 16)
                    } else {
                        // Fallback on earlier versions
                    }

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
    }

    private func fetchWeatherForLocation() {
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

private extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(rightValue)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

#Preview {
    WeatherDetailsView(locationName: "San Francisco")
}
