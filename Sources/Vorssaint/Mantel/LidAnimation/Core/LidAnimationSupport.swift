// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Ranges and defaults follow Mac Duo (github.com/DhananjayBhosale/MacDuo, MIT).

import Foundation

/// The pure half of Mantel's lid animation: setting ranges and the pause
/// rule. The motion model itself is Mac Duo's (`FoldMath`, `LidStillness`,
/// `FoldVisualAnimation`, `LidMotionReference`).
enum LidAnimationSupport {
    static let clearAngleRange = 60.0...140.0
    static let defaultClearAngle = 105.0
    static let stillnessDelayRange = 1.0...5.0
    static let defaultStillnessDelay = 2.0
    static let unitRange = 0.0...1.0
    static let defaultPerspective = 0.7
    static let defaultSoftness = 0.65
    static let defaultShadow = 0.65
    /// How far above "Starts below" the lid has to open to lift a pause, so
    /// the sensor's one-degree jitter at the threshold cannot end it.
    static let pauseReleaseMargin = 5.0
    /// Mac Duo starts capturing a little before the effect so the first
    /// visible frame is fresh.
    static let captureLead = 14.0
    /// The scripted sweep of "Test on the desktop".
    static let testDuration: TimeInterval = 8

    static func clamped(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    static func sanitizedClearAngle(_ value: Double) -> Double {
        clamped(value, to: clearAngleRange, fallback: defaultClearAngle)
    }

    static func sanitizedStillnessDelay(_ value: Double) -> Double {
        clamped(value, to: stillnessDelayRange, fallback: defaultStillnessDelay).rounded()
    }

    static func sanitizedUnit(_ value: Double, fallback: Double) -> Double {
        clamped(value, to: unitRange, fallback: fallback)
    }

    /// A pause (Esc or the shortcut) lasts until the lid is opened clearly
    /// above the angle where the effect starts. A missing reading never
    /// lifts it.
    static func releasesPause(angle: Double?, clearAngle: Double) -> Bool {
        guard let angle, angle.isFinite else { return false }
        return angle >= sanitizedClearAngle(clearAngle) + pauseReleaseMargin
    }

    /// Whether the desktop stream should run: while testing, or while the
    /// lid is near or below the start angle and the effect is not cleared.
    static func shouldCapture(angle: Double?, reference: Double, testing: Bool,
                              paused: Bool, clearedForStillness: Bool) -> Bool {
        if testing { return true }
        guard !paused, !clearedForStillness, let angle, angle.isFinite else { return false }
        return angle < reference + captureLead
    }

    /// The test's scripted lid angle at progress `t` (0...1): it closes from
    /// just above the start angle to near shut and opens again (Mac Duo's
    /// `demoAngle`).
    static func testAngle(at t: Double, clearAngle: Double) -> Double {
        let clear = sanitizedClearAngle(clearAngle)
        return clear + 8 - sin(min(1, max(0, t)) * .pi) * (clear - 12)
    }
}
