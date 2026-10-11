// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Gestures, mirror and lock screen after Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// boringNotch/ContentView.swift (handleDownGesture, handleUpGesture), extensions/PanGesture.swift,
// components/Webcam/WebcamView.swift, boringNotchApp.swift (showOnLockScreen), models/Constants.swift.

import CoreGraphics
import Foundation

/// SPEC §3D's pick-one for gestures. Boring Notch: pull down on the closed
/// notch to open it, push up on the open notch to close it, nothing
/// sideways. Vorssaint: its own swipes, with sideways skipping tracks.
enum BoringNotchGestureStyle: String, CaseIterable {
    case boringNotch, vorssaint

    static let fallback: BoringNotchGestureStyle = .boringNotch

    static func sanitized(_ raw: String?) -> BoringNotchGestureStyle {
        raw.flatMap(BoringNotchGestureStyle.init(rawValue:)) ?? fallback
    }
}

/// Boring Notch's three sensitivities: how far the fingers travel, in
/// points, before the notch opens or closes (`gestureSensitivity`).
enum BoringNotchGestureSensitivity: Int, CaseIterable {
    case high = 100, medium = 200, low = 300

    static let fallback: BoringNotchGestureSensitivity = .medium

    static func sanitized(_ raw: Int) -> BoringNotchGestureSensitivity {
        BoringNotchGestureSensitivity(rawValue: raw) ?? fallback
    }
}

/// Boring Notch's mirror (`mirrorShape`): a rounded square or a circle, as a
/// tile in its own tab. Vorssaint keeps its wide preview with the camera menu.
enum BoringNotchMirrorShape: String, CaseIterable {
    case rectangle, circle, vorssaint

    static let fallback: BoringNotchMirrorShape = .rectangle

    static func sanitized(_ raw: String?) -> BoringNotchMirrorShape {
        raw.flatMap(BoringNotchMirrorShape.init(rawValue:)) ?? fallback
    }

    var isBoringNotch: Bool { self != .vorssaint }

    /// Boring Notch's corner for the rectangle (the open album art's), and a
    /// radius past half the side for the circle.
    func cornerRadius(side: CGFloat) -> CGFloat {
        switch self {
        case .rectangle: return BoringNotchMetrics.openArtRadius
        case .circle, .vorssaint: return side / 2
        }
    }
}

/// SPEC §3D's pick-one for the lock screen, used while Vorssaint's own
/// "show on the lock screen" switch is on. Boring Notch keeps the notch on
/// the lock screen and nothing else: its outline, the cover beside the
/// camera and its bars. Vorssaint adds its player under the clock and its
/// row of activities.
enum BoringNotchLockScreenStyle: String, CaseIterable {
    case boringNotch, vorssaint

    static let fallback: BoringNotchLockScreenStyle = .boringNotch

    static func sanitized(_ raw: String?) -> BoringNotchLockScreenStyle {
        raw.flatMap(BoringNotchLockScreenStyle.init(rawValue:)) ?? fallback
    }
}

/// Boring Notch's pan gesture on Vorssaint's scroll events. Travel builds up
/// in the action's direction and resets when it turns back; the action fires
/// once per swipe, when the travel passes the sensitivity. A pause of
/// 0.3 s or a lift ends the swipe (PanGesture.swift's end timeout).
struct BoringNotchGestureTracker {
    enum Action: Equatable { case open, close }

    private var travel = 0.0
    private var fired = false
    private var lastTimestamp: TimeInterval?
    static let endTimeout: TimeInterval = 0.3

    /// `x` and `y` come from Vorssaint's `NotchGestureSupport.movement`:
    /// a positive `y` pulls down, toward opening.
    mutating func handle(x: Double, y: Double, timestamp: TimeInterval, ended: Bool,
                         allowVertical: Bool, expanded: Bool,
                         sensitivity: Double, closes: Bool) -> Action? {
        guard x.isFinite, y.isFinite, timestamp.isFinite else { self = Self(); return nil }
        if let last = lastTimestamp, timestamp < last || timestamp - last > Self.endTimeout { self = Self() }
        lastTimestamp = timestamp
        if ended { self = Self(); return nil }
        // Only travel mostly along the vertical axis counts (1.5×, as Boring Notch).
        guard allowVertical, abs(y) > 0.2, abs(y) >= abs(x) * 1.5 else { return nil }
        let toward = y * (expanded ? -1 : 1)
        travel = toward > 0 ? travel + toward : 0
        guard !fired, travel > sensitivity, !expanded || closes else { return nil }
        fired = true
        return expanded ? .close : .open
    }
}
