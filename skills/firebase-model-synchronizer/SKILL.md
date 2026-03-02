---
name: firebase-model-synchronizer
description: Ensures Swift data models are correctly mapped to Firebase Firestore documents. Use when adding or updating fields in Location.swift or other models.
---

# Firebase Model Synchronizer

This skill ensures consistent data mapping between Swift `Codable` structs and Firestore documents.

## Model Pattern

Models in this project typically serve two purposes:
1. **API Integration**: Mapping from external APIs (like OpenStreetMap).
2. **Database Integration**: Mapping to/from Firestore.

### Example: Location.swift

```swift
struct Location: Codable, Hashable {
    let city: String
    let state: String
    let latitude: Double?
    let longitude: Double?

    // Firestore Initializer
    init?(document: [String: Any]) {
        guard let city = document["city"] as? String,
              let state = document["state"] as? String else { return nil }

        self.city = city
        self.state = state
        self.latitude = document["latitude"] as? Double
        self.longitude = document["longitude"] as? Double
    }

    // To Firestore Dictionary
    func toFirestore() -> [String: Any] {
        return [
            "city": city,
            "state": state,
            "latitude": latitude as Any,
            "longitude": longitude as Any
        ]
    }
}
```

## Guidelines

1. **Firestore Dictionary**: Always provide an `init?(document: [String: Any])` and a `toFirestore() -> [String: Any]` method (or use `Codable` with `Firestore.Encoder`).
2. **CodingKeys**: Use `CodingKeys` to map Swift property names to external API names (e.g., `display_name` to `displayName`).
3. **Optionality**: Be defensive with optional fields (e.g., `latitude`, `longitude`) as data from external sources or old database entries might be missing.
4. **Validation**: Validate required fields in the initializer and return `nil` if the document is invalid.
5. **DatabaseManager**: Update `DatabaseManager.swift` methods when models change to ensure fetching and saving logic remains correct.
