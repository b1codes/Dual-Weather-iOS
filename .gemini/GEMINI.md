# Dual Weather iOS - Project Overview

Dual Weather is a modern iOS application built with SwiftUI that provides real-time weather information using Apple's WeatherKit. The app distinguishes itself by focusing on displaying weather data in both imperial and metric units simultaneously or with easy toggling.

## Architecture & Technologies

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Weather Data:** Apple WeatherKit
- **Location Services:** CoreLocation
- **Backend/Database:** Firebase Firestore (for saving locations)
- **Geocoding:** CLGeocoder and OpenStreetMap Nominatim API
- **Design Pattern:** MVVM (Model-View-ViewModel)

## Directory Structure

- `Dual Weather iOS/`: Main source code directory.
    - `Components/`: Small, reusable SwiftUI components (e.g., `LocationCard`, `MapThumbnail`).
    - `Services and Managers/`: Core business logic.
        - `WeatherService.swift`: Contains `WeatherViewModel` for fetching weather and managing location updates.
        - `LocationService.swift`: Handles geocoding and external location searches.
        - `DatabaseManager.swift`: Manages Firebase Firestore interactions.
    - `Tabs/`: Primary view controllers for the app's main navigation tabs (`Home`, `Search`, `Saved`, `Convert`, `Settings`).
    - `Types/`: Data models (e.g., `Location.swift`).
    - `Assets.xcassets/`: App icons, colors, and static images.

## Key Features

1. **Real-time Weather:** Fetches current weather for the user's location or a searched location.
2. **Dual Measurements:** Focus on presenting data in both imperial (Fahrenheit, mph) and metric (Celsius, km/h) units.
3. **Location Search:** Search for any city worldwide using OpenStreetMap's Nominatim API.
4. **Saved Locations:** Persist favorite locations using Firebase Firestore.
5. **Unit Conversion:** Dedicated tab for converting weather-related measurements.

## Development & Building

### Prerequisites
- **Xcode:** 15.0 or later recommended.
- **iOS Target:** iOS 16.0 or later.
- **Developer Account:** WeatherKit requires an active Apple Developer Program membership and the WeatherKit capability enabled in the project and App ID.
- **Firebase:** Requires a `GoogleService-Info.plist` file in the project root to enable Firestore functionality.

### Build Instructions
1. Open `Dual Weather iOS/Dual Weather iOS.xcodeproj` in Xcode.
2. Ensure the `Dual Weather iOS` target is selected.
3. Add your `GoogleService-Info.plist` to the project if not already present.
4. Set your Development Team in the "Signing & Capabilities" tab.
5. Build and run (Cmd + R) on a physical device or simulator.

### Testing
- Unit tests are located in the `Dual Weather iOSTests/` directory.
- UI tests are located in the `Dual Weather iOSUITests/` directory.
- Use Cmd + U to run all tests in Xcode.

## Coding Conventions
- **Naming:** Follow standard Swift API Design Guidelines.
- **UI:** Prefer declarative SwiftUI over UIKit wherever possible.
- **Concurrency:** Uses modern Swift Concurrency (async/await) for network calls and asynchronous tasks.
- **Views:** Keep views small and modular, extracting logic into ViewModels.
