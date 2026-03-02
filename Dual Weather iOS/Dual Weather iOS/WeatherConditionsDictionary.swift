//
//  weatherConditionsDictionary.swift
//  Dual Weather iOS
//
//  Created by Brandon Lamer-Connolly on 1/26/25.
//

import Foundation
import WeatherKit
import SwiftUI

var weatherConditionsDictionary: [WeatherCondition: [Bool: String]] = [ // Bool true = isDaylight , false = !isDaylight
    .blowingDust: [true: "sun.dust.fill", false: "moon.dust.fill"],
    .clear: [true: "sun.max.fill", false: "moon.stars.fill"],
    .cloudy: [true: "cloud.fill", false: "cloud.fill"],
    .foggy: [true: "cloud.fog.fill", false: "cloud.fog.fill"],
    .haze: [true: "sun.haze.fill", false: "moon.haze.fill"],
    .mostlyClear: [true: "sun.max.fill", false: "moon.stars.fill"],
    .mostlyCloudy: [true: "cloud.fill", false: "cloud.fill"],
    .partlyCloudy: [true: "cloud.sun.fill", false: "cloud.moon.fill"],
    .smoky: [true: "smoke.fill", false: "smoke.fill"],
    .breezy: [true: "wind", false: "wind"],
    .windy: [true: "wind", false: "wind"],
    .drizzle: [true: "cloud.drizzle.fill", false: "cloud.drizzle.fill"],
    .heavyRain: [true: "cloud.heavyrain.fill", false: "cloud.heavyrain.fill"],
    .isolatedThunderstorms: [true: "cloud.sun.bolt.fill", false: "cloud.moon.bolt.fill"],
    .rain: [true: "cloud.rain.fill", false: "cloud.rain.fill"],
    .sunShowers: [true: "sun.rain.fill", false: "moon.rain.fill"],
    .scatteredThunderstorms: [true: "cloud.sun.bolt.fill", false: "cloud.moon.bolt.fill"],
    .strongStorms: [true: "cloud.bolt.rain.fill", false: "cloud.bolt.rain.fill"],
    .thunderstorms: [true: "cloud.bolt.fill", false: "cloud.bolt.fill"],
    .frigid: [true: "thermometer.snowflake", false: "thermometer.snowflake"],
    .hail: [true: "cloud.hail.fill", false: "cloud.hail.fill"],
    .hot: [true: "thermometer.sun.fill", false: "thermometer.sun.fill"],
    .flurries: [true: "snowflake", false: "snowflake"],
    .sleet: [true: "cloud.sleet.fill", false: "cloud.sleet.fill"],
    .snow: [true: "snowflake", false: "snowflake"],
    .sunFlurries: [true: "sun.snow.fill", false: "sun.snow.fill"],
    .wintryMix: [true: "snowflake", false: "snowflake"],
    .blizzard: [true: "cloud.snow.fill", false: "cloud.snow.fill"],
    .blowingSnow: [true: "wind.snow", false: "wind.snow"],
    .freezingDrizzle: [true: "cloud.drizzle.fill", false: "cloud.drizzle.fill"],
    .freezingRain: [true: "cloud.rain.fill", false: "cloud.rain.fill"],
    .heavySnow: [true: "cloud.snow.fill", false: "cloud.snow.fill"],
    .hurricane: [true: "hurricane", false: "hurricane"],
    .tropicalStorm: [true: "tropicalstorm", false: "tropicalstorm"]
]

var weatherEmojiDictionary: [WeatherCondition: String] = [
    .blowingDust: "🌪️",
    .clear: "☀️",
    .cloudy: "☁️",
    .foggy: "🌫️",
    .haze: "🌫️",
    .mostlyClear: "🌤️",
    .mostlyCloudy: "🌥️",
    .partlyCloudy: "⛅",
    .smoky: "💨",
    .breezy: "🌬️",
    .windy: "💨",
    .drizzle: "🌦️",
    .heavyRain: "🌧️",
    .isolatedThunderstorms: "⛈️",
    .rain: "🌧️",
    .sunShowers: "🌦️",
    .scatteredThunderstorms: "⛈️",
    .strongStorms: "🌩️",
    .thunderstorms: "⛈️",
    .frigid: "🥶",
    .hail: "🌨️",
    .hot: "🥵",
    .flurries: "🌨️",
    .sleet: "🌨️",
    .snow: "❄️",
    .sunFlurries: "🌦️",
    .wintryMix: "🌨️",
    .blizzard: "❄️",
    .blowingSnow: "❄️",
    .freezingDrizzle: "🌧️",
    .freezingRain: "🌧️",
    .heavySnow: "❄️",
    .hurricane: "🌀",
    .tropicalStorm: "🌀"
]

var weatherBackgroundColors: [WeatherCondition: [Color]] = [
    .clear: [Color.blue, Color.cyan],
    .mostlyClear: [Color.blue, Color.cyan],
    .partlyCloudy: [Color.blue, Color.gray],
    .mostlyCloudy: [Color.gray, Color.blue],
    .cloudy: [Color.gray, Color.secondary],
    .foggy: [Color.gray.opacity(0.8), Color.gray],
    .haze: [Color.orange.opacity(0.3), Color.blue.opacity(0.3)],
    .windy: [Color.blue.opacity(0.5), Color.gray],
    .breezy: [Color.blue.opacity(0.4), Color.cyan.opacity(0.4)],
    .rain: [Color.blue.opacity(0.8), Color.black.opacity(0.6)],
    .heavyRain: [Color.blue, Color.black],
    .drizzle: [Color.blue.opacity(0.6), Color.gray],
    .sunShowers: [Color.yellow.opacity(0.5), Color.blue.opacity(0.5)],
    .thunderstorms: [Color.purple.opacity(0.7), Color.black],
    .scatteredThunderstorms: [Color.purple.opacity(0.5), Color.black.opacity(0.8)],
    .strongStorms: [Color.purple, Color.black],
    .snow: [Color.white, Color.blue.opacity(0.3)],
    .heavySnow: [Color.white, Color.gray.opacity(0.5)],
    .flurries: [Color.white.opacity(0.8), Color.blue.opacity(0.2)],
    .blizzard: [Color.white, Color.gray],
    .frigid: [Color.blue, Color.white],
    .hot: [Color.red, Color.orange],
    .hurricane: [Color.black, Color.red.opacity(0.5)],
    .tropicalStorm: [Color.black, Color.blue.opacity(0.5)]
]
