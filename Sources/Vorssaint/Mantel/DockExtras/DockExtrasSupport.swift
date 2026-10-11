// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Behaviour follows DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// DockDoor/Utilities/DockObserver.swift (handleCmdRightClickQuit, handleDockScroll).

import Foundation

/// The pure half of Mantel's DockDoor extras: which extras are on, and the
/// decisions their hooks make. Each extra is its own Features hub switch
/// (SPEC §3C) and changes nothing while it is off.
enum DockExtrasSupport {
    /// Spotify and Apple Music: scrolling on their icon can set the volume.
    static let mediaBundleIDs: Set<String> = ["com.spotify.client", "com.apple.Music"]
    /// Never quit from the Dock: Finder relaunches itself, and quitting
    /// Mantel from its own Dock tap would end the tap mid-event.
    static let protectedBundleIDs: Set<String> = ["com.apple.finder"]
    /// DockDoor's debounce between two scroll actions on an icon.
    static let scrollDebounce: TimeInterval = 0.3
    /// DockDoor ignores scroll deltas below this as noise.
    static let scrollNoise = 0.1
    /// DockDoor's volume sensitivity per scroll unit.
    static let volumeStep = 0.015

    static func isOn(_ feature: AppFeature, key: String, in defaults: UserDefaults = .standard) -> Bool {
        feature.isAvailable(in: defaults) && defaults.bool(forKey: key)
    }

    static var quitClickOn: Bool { isOn(.dockQuitClick, key: DefaultsKey.dockQuitClickEnabled) }
    static var scrollOn: Bool { isOn(.dockScroll, key: DefaultsKey.dockScrollEnabled) }
    static var massActionsOn: Bool { isOn(.dockPreviewMassActions, key: DefaultsKey.dockPreviewMassActionsEnabled) }
    static var windowButtonsOn: Bool {
        isOn(.dockPreviewWindowButtons, key: DefaultsKey.dockPreviewWindowButtonsEnabled)
    }

    /// Whether the Dock tap should run for the extras alone.
    static var wantsDockTap: Bool { quitClickOn || scrollOn }

    enum QuitIntent: Equatable { case none, quit, forceQuit }

    /// ⌘ right-click quits, ⌥⌘ right-click force-quits (DockDoor). Control
    /// or Shift keep the Dock's own menu, so nothing else is taken over.
    static func quitIntent(command: Bool, option: Bool, control: Bool, shift: Bool) -> QuitIntent {
        guard command, !control, !shift else { return .none }
        return option ? .forceQuit : .quit
    }

    static func canQuit(bundleID: String?, isOwnApp: Bool) -> Bool {
        guard !isOwnApp else { return false }
        return !(bundleID.map(protectedBundleIDs.contains) ?? false)
    }

    enum ScrollAction: Equatable { case none, show, hide, volume(Double) }

    /// One scroll on an icon. `deltaY` is the wheel's raw axis-1 delta and
    /// `naturalScrolling` the device's inversion, so "up" means the same
    /// gesture on every Mac (DockDoor normalizes the same way). Media apps
    /// turn the volume when `mediaVolume` is on; everything else shows (up)
    /// or hides (down), at most once per debounce.
    static func scrollAction(deltaY: Double, naturalScrolling: Bool, isMediaApp: Bool, mediaVolume: Bool,
                             sinceLastAction: TimeInterval) -> ScrollAction {
        guard deltaY.isFinite, abs(deltaY) > scrollNoise else { return .none }
        let normalized = naturalScrolling ? -deltaY : deltaY
        if isMediaApp, mediaVolume { return .volume(normalized * volumeStep) }
        guard sinceLastAction >= scrollDebounce else { return .none }
        return normalized > 0 ? .show : .hide
    }

    static func nextVolume(current: Double, change: Double) -> Double {
        min(1, max(0, current + change))
    }
}
