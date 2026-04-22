---
name: mvvm-boilerplate-skill
description: Generates ViewModel and View pairings following the MVVM pattern used in Dual Weather iOS. Use when creating new tabs or features.
---

# MVVM Boilerplate Skill

This skill guides the creation of consistent View and ViewModel pairings for new features and tabs.

## Project Structure

- **ViewModels**: Place in `Dual Weather iOS/Dual Weather iOS/Services and Managers/`.
- **Views**: Place in `Dual Weather iOS/Dual Weather iOS/Tabs/` for main navigation tabs, or `Components/` for sub-features.

## ViewModel Template

```swift
import Foundation
import Combine

class NewFeatureViewModel: ObservableObject {
    @Published var data: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    init() {
        // Initial setup
    }

    func fetchData() async {
        await MainActor.run { self.isLoading = true }

        do {
            // Simulated network call
            try await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                self.data = "Success"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
```

## View Template

```swift
import SwiftUI

struct NewFeatureView: View {
    @StateObject private var viewModel = NewFeatureViewModel()

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else if let data = viewModel.data {
                Text(data)
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchData()
            }
        }
    }
}

#Preview {
    NewFeatureView()
}
```

## Guidelines

1. **State Injection**: Prefer `@StateObject` for the View's primary ViewModel.
2. **Concurrency**: Use `async/await` for asynchronous tasks. Always use `await MainActor.run` when updating `@Published` properties from background tasks.
3. **Delegation**: If the ViewModel needs to handle protocols (e.g., `CLLocationManagerDelegate`), ensure it inherits from `NSObject`.
4. **Consistency**: Use existing services (e.g., `WeatherService`, `DatabaseManager`) where possible instead of recreating logic.
