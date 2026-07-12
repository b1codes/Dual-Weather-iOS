//
//  DesignSystem.swift
//  Dual Weather iOS
//
//  Design tokens from .claude/context/llc-swift/ (Technical Luxury / Refractive Aperture).
//  Values must stay in sync with DESIGN.md.
//

import SwiftUI

enum Radius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
}

enum Spacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
}

extension Color {
    /// The origin point of the thermal-glow touch response. Interaction-only —
    /// never a resting-state fill, icon tint, or text color (the One Glow Rule).
    static let solarFlareCore = Color(red: 1.0, green: 0x3B / 255.0, blue: 0x30 / 255.0)
    /// The outer radius of the thermal glow as it expands and cools.
    static let solarFlareCorona = Color(red: 1.0, green: 0x95 / 255.0, blue: 0x00 / 255.0)
    /// The only border treatment in the system: a 0.5pt stroke defining a glass surface's edge.
    static let glassEdge = Color.white.opacity(0.2)
}

private struct GlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.glassEdge, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    /// Glass Surface + Glass Edge: the base material for every card, panel, and sheet.
    /// Never pair with `.shadow()` — see the No-Shadow Rule in DESIGN.md.
    func glassSurface(cornerRadius: CGFloat = Radius.large) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius))
    }
}

/// Montserrat (structural headlines) + Open Sans (dense technical body text).
/// PostScript names below are runtime-verified via `UIFont.fontNames(forFamilyName:)` —
/// both families ship as variable fonts, and named-instance resolution on iOS doesn't
/// always match the names reported by static font tooling (Open Sans's Regular instance
/// in particular resolves to "OpenSans-Regular", not "OpenSansRoman-Regular"). Reverify
/// if the bundled .ttf files are ever swapped.
enum AppFont {
    /// 34pt ExtraBold. The location name / hero moment atop the weather card.
    static func display(_ size: CGFloat = 34) -> Font {
        .custom("Montserrat-ExtraBold", size: size, relativeTo: .largeTitle)
    }

    /// 17pt Bold. Stat-row labels ("Temperature," "Wind," ...).
    static func headline(_ size: CGFloat = 17) -> Font {
        .custom("Montserrat-Bold", size: size, relativeTo: .headline)
    }

    /// 20pt SemiBold. The current-conditions description ("Partly Cloudy").
    static func title(_ size: CGFloat = 20) -> Font {
        .custom("Montserrat-SemiBold", size: size, relativeTo: .title3)
    }

    /// 17pt Regular. Dual-unit values — never heavier than its counterpart unit.
    static func body(_ size: CGFloat = 17) -> Font {
        .custom("OpenSans-Regular", size: size, relativeTo: .body)
    }

    /// 13pt Light. Secondary metadata: saved-location subtitles, timestamps, captions.
    static func label(_ size: CGFloat = 13) -> Font {
        .custom("OpenSansRoman-Light", size: size, relativeTo: .footnote)
    }
}
