//
//  Location.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 2/2/25.
//

import Foundation

let stateAbbreviations = [
    "Alabama": "AL",
    "Alaska": "AK",
    "Arizona": "AZ",
    "Arkansas": "AR",
    "California": "CA",
    "Colorado": "CO",
    "Connecticut": "CT",
    "Delaware": "DE",
    "Florida": "FL",
    "Georgia": "GA",
    "Hawaii": "HI",
    "Idaho": "ID",
    "Illinois": "IL",
    "Indiana": "IN",
    "Iowa": "IA",
    "Kansas": "KS",
    "Kentucky": "KY",
    "Louisiana": "LA",
    "Maine": "ME",
    "Maryland": "MD",
    "Massachusetts": "MA",
    "Michigan": "MI",
    "Minnesota": "MN",
    "Mississippi": "MS",
    "Missouri": "MO",
    "Montana": "MT",
    "Nebraska": "NE",
    "Nevada": "NV",
    "New Hampshire": "NH",
    "New Jersey": "NJ",
    "New Mexico": "NM",
    "New York": "NY",
    "North Carolina": "NC",
    "North Dakota": "ND",
    "Ohio": "OH",
    "Oklahoma": "OK",
    "Oregon": "OR",
    "Pennsylvania": "PA",
    "Rhode Island": "RI",
    "South Carolina": "SC",
    "South Dakota": "SD",
    "Tennessee": "TN",
    "Texas": "TX",
    "Utah": "UT",
    "Vermont": "VT",
    "Virginia": "VA",
    "Washington": "WA",
    "West Virginia": "WV",
    "Wisconsin": "WI",
    "Wyoming": "WY"
]

func stateToAbbreviation(_ state: String) -> String? {
    stateAbbreviations[state]
}

struct Location: Codable, Hashable {
    let city: String
    let state: String
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case lat, lon
    }

    // Custom initializer for decoding from JSON
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let displayName = try values.decode(String.self, forKey: .displayName)
        let latString = try? values.decode(String.self, forKey: .lat)
        let lonString = try? values.decode(String.self, forKey: .lon)

        let components = displayName.components(separatedBy: ", ")
        self.city = components.first.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown City"
        self.state = components.dropFirst().dropFirst().first ?? "Unknown State"
        self.latitude = latString.flatMap(Double.init)
        self.longitude = lonString.flatMap(Double.init)
    }

    // Encoding function to conform to `Encodable`
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let displayName = "\(city), \(state)"
        try container.encode(displayName, forKey: .displayName)

        if let latitude = latitude {
            try container.encode(String(latitude), forKey: .lat)
        }

        if let longitude = longitude {
            try container.encode(String(longitude), forKey: .lon)
        }
    }

    init(city: String, state: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.city = city
        self.state = state
        self.latitude = latitude
        self.longitude = longitude
    }

    init?(document: [String: Any]) {
        guard let city = document["city"] as? String,
              let state = document["state"] as? String else { return nil }

        self.city = city
        self.state = state
        self.latitude = document["latitude"] as? Double
        self.longitude = document["longitude"] as? Double
    }

    func locationString() -> String {
        return "\(city), \(stateToAbbreviation(state) ?? state)"
    }
}
