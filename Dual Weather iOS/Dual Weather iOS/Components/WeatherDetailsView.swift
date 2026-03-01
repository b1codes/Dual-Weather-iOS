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
    
    let columns = [
        GridItem(.flexible(), spacing: 20, alignment: .trailing),
        GridItem(.flexible(), spacing: 20, alignment: .center),
        GridItem(.flexible(), spacing: 20, alignment: .leading),
    ]
    
    // Initialize with locationName
    init(locationName: String) {
        self.locationName = locationName
    }

    var dynamicBackground: some View {
        Group {
            if backgroundTheme == 1, let condition = weatherViewModel.currentWeather?.currentWeather.condition {
                let colors = WeatherBackgroundColors[condition] ?? [Color.blue, Color.cyan]
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
            
            VStack {
                if let currentWeather = weatherViewModel.currentWeather {
                    Text("\(locationName)")
                        .font(.title)
                        .padding()
                    
                    if useEmoji {
                        Text(WeatherEmojiDictionary[currentWeather.currentWeather.condition] ?? "❓")
                            .font(.system(size: 150))
                            .padding()
                    } else {
                        Image(systemName: WeatherConditionsDictionary[currentWeather.currentWeather.condition]?[currentWeather.currentWeather.isDaylight] ?? "questionmark.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200)
                            .padding()
                    }
                    
                    Text("Conditions: \(currentWeather.currentWeather.condition.description)")
                        .font(.headline)
                        .padding()
                    
                    LazyVGrid(columns: columns, spacing: 25) {
                        Text("\(Int(currentWeather.currentWeather.temperature.value.rounded()))°C")
                            .font(.subheadline)
          
                        
                        Text("Temperature")
                            .font(.headline)

                        
                        Text("\(Int(currentWeather.currentWeather.temperature.converted(to: .fahrenheit).value.rounded()))°F")
                            .font(.subheadline)
             
                        
                        Text("\(Int(currentWeather.currentWeather.wind.speed.value.rounded())) km/h")
                            .font(.subheadline)
                        
                        Text("Wind")
                            .font(.headline)

                        Text("\(Int(currentWeather.currentWeather.wind.speed.converted(to: .milesPerHour).value.rounded())) mph")
                            .font(.subheadline)
                        
                        
                        Text("\(Int(currentWeather.currentWeather.apparentTemperature.value.rounded()))°C")
                            .font(.subheadline)
          
                        
                        Text("Feels Like")
                            .font(.headline)
                        
                        Text("\(Int(currentWeather.currentWeather.apparentTemperature.converted(to: .fahrenheit).value.rounded()))°F")
                            .font(.subheadline)
             
                    }
                    .padding()
                    
                    Text("Humidity: \(currentWeather.currentWeather.humidity.formatted(.percent))")
                        .font(.headline)
                        .padding()
                    
                    Text("UV Index: \(currentWeather.currentWeather.uvIndex.value)")
                        .font(.headline)
                        .padding()
                    
                    
                } else if let error = weatherViewModel.locationError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    Text("Fetching weather for \(locationName)...")
                        .padding()
                }
            }
        }
        .onAppear {
            fetchWeatherForLocation()
        }
    }

    // Function to fetch weather for the location name
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

#Preview {
    WeatherDetailsView(locationName: "San Francisco")
}
