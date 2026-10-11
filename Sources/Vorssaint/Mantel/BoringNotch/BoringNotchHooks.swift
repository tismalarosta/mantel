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

extension BoringNotchHooks {
    /// Boring Notch's swipes, one per island (SPEC §3D pick-one).
    private static var gestureTracker = BoringNotchGestureTracker()

    /// Whether Boring Notch's gestures replace Vorssaint's. Vorssaint's own
    /// switch still decides whether the island takes gestures at all.
    static func handlesGestures(defaults: UserDefaults = .standard) -> Bool {
        guard NotchDesign.isBoringNotch else { return false }
        return BoringNotchGestureStyle.sanitized(defaults.string(forKey: DefaultsKey.notchBoringGestureStyle)) == .boringNotch
    }

    /// Boring Notch's answer to one scroll event over the island. Like its
    /// pan gesture, a swipe counts anywhere on the notch, except on a control
    /// or, once open, over a list that scrolls (its calendar strip, the shelf).
    static func gestureAction(x: Double, y: Double, timestamp: TimeInterval, ended: Bool, expanded: Bool,
                              inHeader: Bool, control: Bool, scroll: Bool,
                              defaults: UserDefaults = .standard) -> BoringNotchGestureTracker.Action? {
        let sensitivity = BoringNotchGestureSensitivity.sanitized(defaults.integer(forKey: DefaultsKey.notchBoringGestureSensitivity))
        let closes = defaults.object(forKey: DefaultsKey.notchBoringCloseGesture) as? Bool ?? true
        return gestureTracker.handle(x: x, y: y, timestamp: timestamp, ended: ended,
                                     allowVertical: !control && (!expanded || inHeader || !scroll),
                                     expanded: expanded, sensitivity: Double(sensitivity.rawValue), closes: closes)
    }

    /// Whether the lock screen shows only Boring Notch's notch.
    static func lockScreenIsBoring(defaults: UserDefaults = .standard) -> Bool {
        guard NotchDesign.isBoringNotch else { return false }
        return BoringNotchLockScreenStyle.sanitized(defaults.string(forKey: DefaultsKey.notchBoringLockScreenStyle)) == .boringNotch
    }

    /// Whether Boring Notch's frame draws the open island, and how big it is.
    static func drawsOpenPage(showingSections: Bool, showingAppPanel: Bool, showingMetric: Bool,
                              selected: NotchModule) -> Bool {
        NotchDesign.isBoringNotch && BoringNotchTabs.drawsOpenPage(
            showingSections: showingSections, showingAppPanel: showingAppPanel,
            showingMetric: showingMetric, selected: selected)
    }

    static func openSize(selected: NotchModule, vorssaint: CGSize, defaults: UserDefaults = .standard) -> CGSize {
        let mirror = BoringNotchMirrorShape.sanitized(defaults.string(forKey: DefaultsKey.notchBoringMirrorShape))
        return BoringNotchTabs.openSize(selected: selected, vorssaint: vorssaint, mirrorIsBoringNotch: mirror.isBoringNotch)
    }
}
