# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an Xcode project — build and run via Xcode or `xcodebuild`. There is no Swift Package Manager setup; dependencies (Firebase) are managed through Xcode's package resolution.

- **Build**: Open `Dual Weather iOS/Dual Weather iOS.xcodeproj` in Xcode, then Cmd+B
- **Run**: Cmd+R (requires a physical device for WeatherKit and location features)
- **Test**: Cmd+U, or via CLI:
  ```bash
  xcodebuild test -project "Dual Weather iOS/Dual Weather iOS.xcodeproj" \
    -scheme "Dual Weather iOS" -destination "platform=iOS Simulator,name=iPhone 16"
  ```
- **Lint**: `swiftlint` (disabled rules: `line_length`, `type_name`, `multiple_closures_with_trailing_closure`)

## Secrets & Configuration

Two config files are required but not committed:
- `Dual Weather iOS/Dual Weather iOS/Config.xcconfig` — copy from `Sample.xcconfig` and add any API keys
- `Dual Weather iOS/Dual Weather iOS/GoogleService-Info.plist` — Firebase config, download from Firebase Console
- `Dual Weather iOS/WeatherKitKey.p8` — Apple WeatherKit private key

## Architecture

**MVVM + Service Layer**, all SwiftUI.

### State Management

`WeatherViewModel` is the central view model — it's an `ObservableObject` that owns `CLLocationManager`, fetches weather from WeatherKit, and handles reverse geocoding. Views observe it via `@StateObject`/`@ObservedObject`. User preferences (emoji icons, background theme) use `@AppStorage`.

### Key Layers

| Layer | Location | Responsibility |
|---|---|---|
| Views/Tabs | `Tabs/` | Tab screens (Home, Search, Saved, Convert, Settings) |
| Reusable UI | `Components/` | WeatherDetailsView, SearchCard, LocationCard, MapThumbnail |
| View Model | `Services and Managers/WeatherViewModel.swift` | Location auth, WeatherKit fetching, geocoding |
| Services | `Services and Managers/LocationService.swift` | Nominatim search, CLGeocoder coordinate lookup |
| Database | `Services and Managers/DatabaseManager.swift` | Firestore CRUD for saved locations |
| Models | `Types/Location.swift` | `Location` struct with custom Codable for Nominatim API |
| Dictionaries | `Types/WeatherConditionsDictionary.swift` | Maps `WeatherCondition` → SF Symbols, emojis, gradient colors |

### Data Flow

1. `WeatherViewModel` requests location auth → receives `CLLocation` updates → fetches `Weather` from WeatherKit → reverse geocodes to city name
2. Search flow: user types in `SearchView` → `LocationService.searchLocations(for:)` hits Nominatim API → results shown in `SearchCard` → user saves to Firestore via `DatabaseManager`
3. Saved locations: `SavedLocationsView` fetches from Firestore on appear, displays in a grid of `LocationCard` views

### External APIs

- **WeatherKit** — Apple's native weather API (requires Apple Developer entitlement)
- **Nominatim (OpenStreetMap)** — Free location search REST API, no key required
- **Firebase Firestore** — Persists user-saved locations
- **MKMapSnapshotter** — Generates map thumbnail images in `MapThumbnail`
