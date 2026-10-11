// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Behaviour follows DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// DockDoor/Utilities/DockObserver.swift (handleCmdRightClickQuit, handleDockScroll,
// handleTitleBarScroll), TrackpadGestureModifier.swift (preview swipes) and
// WindowPreviewHoverContainer.swift (checkForShakeGesture).

import CoreGraphics
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

    static var swipeOn: Bool { isOn(.dockPreviewSwipe, key: DefaultsKey.dockPreviewSwipeEnabled) }
    static var shakeOn: Bool { isOn(.dockPreviewShake, key: DefaultsKey.dockPreviewShakeEnabled) }
    static var titleBarScrollOn: Bool { isOn(.titleBarScroll, key: DefaultsKey.titleBarScrollEnabled) }

    /// Whether the Dock tap should run for the extras alone.
    static var wantsDockTap: Bool { quitClickOn || scrollOn || titleBarScrollOn }
    /// Whether the Dock tap should listen to scrolls: on Dock icons (C7) or
    /// on title bars (C8), both through the one tap.
    static var wantsScrollEvents: Bool { scrollOn || titleBarScrollOn }

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

    // MARK: - C3: swipe on a Dock preview

    enum SwipeDirection: Equatable { case up, down, left, right }
    enum SwipeAction: Equatable { case none, minimize, maximize }

    /// DockDoor's default swipe distance, in points of precise scrolling.
    static let swipeThreshold = 50.0

    /// One finished trackpad swipe, from its summed precise deltas. `natural`
    /// is the device's inversion, so the answer is where the fingers went on
    /// every Mac (DockDoor normalizes only the vertical axis; both are here,
    /// so a side Dock works with either scrolling direction).
    static func swipeDirection(totalX: Double, totalY: Double, natural: Bool,
                               threshold: Double = swipeThreshold) -> SwipeDirection? {
        guard totalX.isFinite, totalY.isFinite else { return nil }
        let up = natural ? -totalY : totalY
        let right = natural ? totalX : -totalX
        if abs(up) > abs(right), abs(up) > threshold { return up > 0 ? .up : .down }
        if abs(right) > abs(up), abs(right) > threshold { return right > 0 ? .right : .left }
        return nil
    }

    /// Toward the Dock minimizes, away from it maximizes (DockDoor's
    /// defaults); a sideways swipe along the Dock does nothing.
    static func swipeAction(_ direction: SwipeDirection?, dock: DockPreviewOrientation) -> SwipeAction {
        guard let direction else { return .none }
        let toward: SwipeDirection
        let away: SwipeDirection
        switch dock {
        case .bottom: (toward, away) = (.down, .up)
        case .left: (toward, away) = (.left, .right)
        case .right: (toward, away) = (.right, .left)
        }
        if direction == toward { return .minimize }
        if direction == away { return .maximize }
        return .none
    }

    // MARK: - C4: shake a dragged preview

    /// DockDoor's shake test, run on the last 20 pointer samples (one every
    /// 50 ms): at least 8 samples, 4 reversals of more than 5 pt each, and
    /// over 100 pt travelled.
    static let shakeSampleInterval: TimeInterval = 0.05
    static let shakeSampleLimit = 20

    static func isShake(_ points: [CGPoint]) -> Bool {
        guard points.count >= 8 else { return false }
        var steps: [CGVector] = []
        var distance: CGFloat = 0
        for i in 1 ..< points.count {
            let step = CGVector(dx: points[i].x - points[i - 1].x, dy: points[i].y - points[i - 1].y)
            steps.append(step)
            distance += hypot(step.dx, step.dy)
        }
        var reversals = 0
        for i in 1 ..< steps.count {
            let previous = steps[i - 1], current = steps[i]
            let flipsX = abs(previous.dx) > 5 && abs(current.dx) > 5 && (previous.dx > 0) != (current.dx > 0)
            let flipsY = abs(previous.dy) > 5 && abs(current.dy) > 5 && (previous.dy > 0) != (current.dy > 0)
            if flipsX || flipsY { reversals += 1 }
        }
        return reversals >= 4 && distance > 100
    }

    // MARK: - C8: scroll on a title bar

    enum TitleBarDecision: Equatable {
        /// Not a title bar scroll: the event goes on to the app.
        case pass
        /// Inside the debounce: kept from the app, nothing done.
        case swallow
        case maximize, centre
    }

    /// DockDoor's debounce between two title bar actions and its noise floor.
    static let titleBarDebounce: TimeInterval = 0.35
    static let titleBarNoise = 0.15
    /// DockDoor's title bar height bounds, measured from the window's top
    /// to the close button, plus 12 pt.
    static let titleBarMinHeight: CGFloat = 48
    static let titleBarMaxHeight: CGFloat = 72

    /// One scroll over a title bar. Momentum (the glide after the fingers
    /// lift) never acts, and a sideways scroll goes on to the app: the
    /// desktop switching DockDoor did there was dropped (SPEC §3C, C8).
    static func titleBarDecision(deltaX: Double, deltaY: Double, natural: Bool, isMomentum: Bool,
                                 sinceLastAction: TimeInterval) -> TitleBarDecision {
        guard deltaX.isFinite, deltaY.isFinite, !isMomentum,
              abs(deltaX) > titleBarNoise || abs(deltaY) > titleBarNoise,
              abs(deltaY) >= abs(deltaX) else { return .pass }
        guard sinceLastAction >= titleBarDebounce else { return .swallow }
        let up = natural ? -deltaY : deltaY
        return up > 0 ? .maximize : .centre
    }

    /// The title bar band of a window, top-left screen coordinates (those
    /// of Accessibility and of CGEvent locations).
    static func titleBarRect(window: CGRect, closeButton: CGRect) -> CGRect {
        let inferred = closeButton.maxY - window.minY + 12
        let height = min(max(inferred, titleBarMinHeight), titleBarMaxHeight, window.height)
        return CGRect(x: window.minX, y: window.minY, width: window.width, height: height)
    }

    /// Whether a window already fills the screen's usable area, so a
    /// maximize would change nothing and leave nothing to restore.
    static func fills(_ frame: CGRect, visibleFrame: CGRect, tolerance: CGFloat = 8) -> Bool {
        abs(frame.minX - visibleFrame.minX) <= tolerance && abs(frame.minY - visibleFrame.minY) <= tolerance
            && abs(frame.width - visibleFrame.width) <= tolerance
            && abs(frame.height - visibleFrame.height) <= tolerance
    }

    /// An AppKit screen rect (bottom-left origin) in top-left coordinates.
    static func topLeftRect(fromAppKit rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
