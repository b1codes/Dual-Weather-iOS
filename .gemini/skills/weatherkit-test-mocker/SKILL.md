---
name: weatherkit-test-mocker
description: Provides strategies for mocking Apple's WeatherKit in unit tests. Use when writing tests for WeatherViewModel or other weather-dependent logic.
---

# WeatherKit Test Mocker

This skill provides patterns for mocking `WeatherKit` to enable reliable unit testing without hitting live APIs.

## Pattern: Protocol Injection

Since `WeatherService` is a final class, we define a protocol that mirrors the functionality we need.

### 1. Define the Protocol

```swift
import WeatherKit
import CoreLocation

protocol WeatherProviding {
    func weather(for location: CLLocation) async throws -> Weather
}

extension WeatherService: WeatherProviding {}
```

### 2. Update the ViewModel

```swift
class WeatherViewModel: ObservableObject {
    private let weatherService: WeatherProviding

    init(weatherService: WeatherProviding = WeatherService()) {
        self.weatherService = weatherService
    }

    // ... existing logic ...
}
```

### 3. Create a Mock

```swift
class MockWeatherService: WeatherProviding {
    var mockWeather: Weather?
    var mockError: Error?

    func weather(for location: CLLocation) async throws -> Weather {
        if let error = mockError {
            throw error
        }
        if let weather = mockWeather {
            return weather
        }
        fatalError("MockWeatherService not configured")
    }
}
```

## Guidelines

1. **Protocol-Oriented**: Always depend on a protocol (e.g., `WeatherProviding`) rather than the concrete `WeatherService` class.
2. **Dependency Injection**: Use initializer injection to provide the mock service in tests.
3. **Mock Data**: Since `Weather` objects are difficult to instantiate manually, consider using `JSONDecoder` with a sample WeatherKit JSON response or a pre-recorded snapshot for tests.
4. **Error Handling**: Use the mock to simulate network failures, API errors, and location-unsupported scenarios to ensure the UI handles them correctly.
