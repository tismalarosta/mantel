// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Layout and symbols from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// components/Live activities/InlineHUD.swift, SystemEventIndicatorModifier.swift,
// BoringBattery.swift, ContentView.swift (sneak peek, battery expanding view).

import CoreGraphics
import Foundation

/// Boring Notch's two closed-notch HUD styles. Stored by raw value.
enum BoringNotchHUDStyle: String, CaseIterable {
    /// The reading inside the widened notch (Boring Notch's "inline HUD").
    case inline
    /// A bar dropping below the notch (Boring Notch's default style).
    case below

    static let fallback: BoringNotchHUDStyle = .inline

    static func sanitized(_ raw: String?) -> BoringNotchHUDStyle {
        raw.flatMap(BoringNotchHUDStyle.init(rawValue:)) ?? fallback
    }
}

/// When the island hides in fullscreen, in the Boring Notch design
/// (Boring Notch's `hideNotchOption`). Stored by raw value.
enum BoringNotchFullscreenPolicy: String, CaseIterable {
    case allApps, mediaApp, never

    static let fallback: BoringNotchFullscreenPolicy = .mediaApp

    static func sanitized(_ raw: String?) -> BoringNotchFullscreenPolicy {
        raw.flatMap(BoringNotchFullscreenPolicy.init(rawValue:)) ?? fallback
    }
}

/// How Vorssaint's notices take Boring Notch's shapes in its design.
enum BoringNotchHUDSupport {
    /// Boring Notch's side width for the inline HUD (100 pt each side).
    static let inlineWing: CGFloat = 100
    /// The bar below the notch, and the track line of the sneak peek.
    static let belowBand: CGFloat = 30
    static let sneakPeekBand: CGFloat = 22
    /// The plug-in banner: status text on one side, the battery on the other.
    static let batteryWing: CGFloat = 130

    /// The notices Boring Notch draws as a HUD.
    static func isHUD(_ event: NotchEvent) -> Bool {
        switch event {
        case .volume, .brightness, .keyboardLight, .microphone: return true
        default: return false
        }
    }

    /// The closed island's size for a notice in Boring Notch's design, or
    /// nil to keep Vorssaint's own layout for that notice.
    static func size(for event: NotchEvent, style: BoringNotchHUDStyle,
                     cameraWidth: CGFloat, stripHeight: CGFloat) -> CGSize? {
        if isHUD(event) {
            switch style {
            case .inline:
                return CGSize(width: cameraWidth + inlineWing * 2, height: stripHeight)
            case .below:
                return CGSize(width: max(cameraWidth + 80, 220), height: stripHeight + belowBand)
            }
        }
        switch event {
        case .battery: return CGSize(width: cameraWidth + batteryWing * 2, height: stripHeight)
        case .track: return CGSize(width: max(cameraWidth + 120, 260), height: stripHeight + sneakPeekBand)
        default: return nil
        }
    }

    /// `InlineHUD.SpeakerSymbol`, `BrightnessSymbol` and the backlight / mic marks.
    static func symbol(for event: NotchEvent, level: Double?) -> String {
        let value = level ?? 0
        switch event {
        case .volume:
            if value <= 0 { return "speaker.slash.fill" }
            if value <= 0.3 { return "speaker.wave.1.fill" }
            if value <= 0.8 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness: return value <= 0.6 ? "sun.min.fill" : "sun.max.fill"
        case .keyboardLight: return value > 0.5 ? "light.max" : "light.min"
        case .microphone: return value > 0 ? "mic.fill" : "mic.slash.fill"
        default: return "circle"
        }
    }

    /// The battery glyph's fill: 0...1, empty when unknown.
    static func batteryFill(percent: Int?) -> Double {
        guard let percent else { return 0 }
        return Double(min(max(percent, 0), 100)) / 100
    }

    /// Boring Notch's battery colours: green charging or plugged, red at 20 %
    /// or below, white otherwise.
    enum BatteryTint: Equatable { case charging, low, normal }

    static func batteryTint(percent: Int?, charging: Bool, plugged: Bool) -> BatteryTint {
        if charging || plugged { return .charging }
        if let percent, percent <= 20 { return .low }
        return .normal
    }

    /// Whether the island hides on a fullscreen Space, in the Boring Notch
    /// design. "Media app only" hides it over the app playing the music,
    /// which is what Boring Notch compares.
    static func hidesInFullscreen(policy: BoringNotchFullscreenPolicy, isFullscreen: Bool,
                                  frontmostBundleID: String?, playerBundleID: String?) -> Bool {
        guard isFullscreen else { return false }
        switch policy {
        case .allApps: return true
        case .never: return false
        case .mediaApp:
            guard let frontmostBundleID, let playerBundleID else { return false }
            return frontmostBundleID == playerBundleID
        }
    }
}
