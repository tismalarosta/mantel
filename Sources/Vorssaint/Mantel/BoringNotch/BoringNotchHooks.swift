// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import AppKit

/// The questions Vorssaint's island asks the Boring Notch design, as free
/// functions on values the island already has, so each hook in NotchService
/// is one line and compiles wherever that code is lifted into a test.
enum BoringNotchHooks {
    /// The app playing the music. Plugged in by the app at launch
    /// (`installAppProviders`); nil until then and in tests.
    static var playerBundleID: () -> String? = { nil }

    /// The closed island's size for a notice in Boring Notch's design, or nil
    /// when it keeps Vorssaint's layout (other notices, a floating capsule).
    static func noticeSize(event: NotchEvent, geometry: NotchGeometry,
                           defaults: UserDefaults = .standard) -> CGSize? {
        guard NotchDesign.isBoringNotch, !geometry.floats, geometry.cameraWidth > 0 else { return nil }
        let style = BoringNotchHUDStyle.sanitized(defaults.string(forKey: DefaultsKey.notchBoringHUDStyle))
        return BoringNotchHUDSupport.size(for: event, style: style,
                                          cameraWidth: geometry.cameraWidth, stripHeight: geometry.stripHeight)
    }

    /// In the Boring Notch design the island hides over fullscreen apps by
    /// its own rule; otherwise Vorssaint's switch decides, as before.
    /// `isFullscreen` asks macOS about Spaces, so it is only evaluated when a
    /// rule needs it (Vorssaint's test pins that a disabled option queries nothing).
    static func hidesInFullscreen(vorssaintSetting: Bool, isFullscreen: @autoclosure () -> Bool,
                                  defaults: UserDefaults = .standard) -> Bool {
        guard NotchDesign.isBoringNotch else { return vorssaintSetting && isFullscreen() }
        let policy = BoringNotchFullscreenPolicy.sanitized(defaults.string(forKey: DefaultsKey.notchBoringFullscreen))
        guard policy != .never else { return false }
        return BoringNotchHUDSupport.hidesInFullscreen(
            policy: policy, isFullscreen: isFullscreen(),
            frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            playerBundleID: playerBundleID())
    }

    /// Whether fullscreen changes need watching at all.
    static func watchesFullscreen(vorssaintSetting: Bool, defaults: UserDefaults = .standard) -> Bool {
        guard NotchDesign.isBoringNotch else { return vorssaintSetting }
        return BoringNotchFullscreenPolicy.sanitized(defaults.string(forKey: DefaultsKey.notchBoringFullscreen)) != .never
    }
}
