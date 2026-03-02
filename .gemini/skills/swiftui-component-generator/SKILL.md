---
name: swiftui-component-generator
description: Generates SwiftUI components following the Dual Weather iOS project's style and architecture. Use when creating new UI elements in the Components/ directory.
---

# SwiftUI Component Generator

This skill guides the creation of modular, reusable SwiftUI components consistent with the Dual Weather iOS codebase.

## Component Structure

- **File Location**: Always place new components in `Dual Weather iOS/Dual Weather iOS/Components/`.
- **Naming**: Use PascalCase (e.g., `WeatherCard.swift`).
- **Protocols**: Implement the `View` protocol.
- **State Management**:
    - Use `@State` for simple local view state.
    - Use `@Binding` for data passed from a parent that needs to be mutated.
    - Use `@ObservedObject` or `@StateObject` for complex logic or data fetching (prefer ViewModels).
    - Use `@AppStorage` for user preferences (e.g., `useEmoji`, `backgroundTheme`).
- **Layout**: Prefer `VStack`, `HStack`, and `ZStack`. Use `LazyVGrid` for grid-like layouts.
- **Styling**: Use system fonts and colors where possible. Adhere to the dual-measurement display pattern (metric and imperial) if showing weather data.

## Template

```swift
import SwiftUI

struct NewComponent: View {
    // Properties
    var title: String

    // State
    @State private var isExpanded: Bool = false
    @AppStorage("useEmoji") private var useEmoji = false

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)

            if isExpanded {
                // Expanded content
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .onTapGesture {
            isExpanded.toggle()
        }
    }
}

#Preview {
    NewComponent(title: "Sample Title")
}
```

## Guidelines

1. **Previews**: Always include a `#Preview` block at the end of the file with sample data.
2. **SF Symbols**: Use `Image(systemName: "...")` for icons.
3. **Dual Units**: If displaying weather, show both Metric (e.g., °C, km/h) and Imperial (e.g., °F, mph) units, or provide a way to toggle.
4. **Modularity**: Keep components focused on a single responsibility.
