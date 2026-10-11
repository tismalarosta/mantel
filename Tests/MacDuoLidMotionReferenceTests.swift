// SPDX-License-Identifier: MIT
// Converted from Mac Duo's Tests/FoldCoreTests/LidMotionReferenceTests.swift
// (github.com/DhananjayBhosale/MacDuo, commit f6862c8), swift-testing -> Vorssaint TestSuite.
// Copyright (c) 2026 Mac Duo contributors, MIT License
// (Sources/Vorssaint/Mantel/LidAnimation/LICENSE-MacDuo.txt). Test bodies unchanged.

import Foundation

import Foundation

/// Feeds a run of readings that the dwell has already classified.
private func hold(_ reference: inout LidMotionReference, at angle: Double,
                  jitter: [Double] = [], clearWhenStill: Bool = true) {
    reference.observe(angle: angle, isStill: true, clearWhenStill: clearWhenStill)
    for offset in jitter {
        reference.observe(angle: angle+offset, isStill: true, clearWhenStill: clearWhenStill)
    }
}

private func move(_ reference: inout LidMotionReference, through angles: [Double],
                  clearWhenStill: Bool = true) {
    for angle in angles {
        reference.observe(angle: angle, isStill: false, clearWhenStill: clearWhenStill)
    }
}

func withoutARestingAngleTheSavedSettingIsTheReference() {
    let reference = LidMotionReference()
    macDuoExpect(reference.restingAngle == nil)
    macDuoExpect(reference.reference(clearAngle: 105) == 105)
    macDuoExpect(reference.reference(clearAngle: 128.3) == 128.3)
    macDuoExpect(reference.reference(clearAngle: 60) == 60)
    macDuoExpect(reference.reference(clearAngle: 140) == 140)
    // The setting keeps its own documented limits.
    macDuoExpect(reference.reference(clearAngle: 40) == 60)
    macDuoExpect(reference.reference(clearAngle: 5) == 60)
    macDuoExpect(reference.reference(clearAngle: 200) == 140)
    macDuoExpect(reference.reference(clearAngle: .nan) == 105)
    macDuoExpect(reference.reference(clearAngle: .infinity) == 105)
    macDuoExpect(reference.reference(clearAngle: -.infinity) == 105)
}

/// The user's example: hold at 90, let the desktop clear, then move to 88. That
/// two-degree move must be measured from 90, not from the saved 128.3 setting.
func aMoveAfterTheDwellIsMeasuredFromTheRestingAngle() {
    var reference = LidMotionReference()
    let saved = 128.3
    hold(&reference, at: 90)
    macDuoExpect(reference.restingAngle == 90)
    macDuoExpect(reference.reference(clearAngle: saved) == 90)

    move(&reference, through: [88])
    macDuoExpect(reference.reference(clearAngle: saved) == 90)   // Retained until the next dwell.
    let rebased = FoldMath.progress(angle: 88, clearAngle: reference.reference(clearAngle: saved))
    let stale = FoldMath.progress(angle: 88, clearAngle: saved)
    macDuoExpect(rebased > 0 && rebased < 0.01)
    macDuoExpect(stale > 0.15)
    macDuoExpect(rebased < stale/10)

    // Continuing to close from the same reference keeps building.
    let further = FoldMath.progress(angle: 75, clearAngle: reference.reference(clearAngle: saved))
    macDuoExpect(further > rebased)
    macDuoExpect(reference.reference(clearAngle: saved) == 90)
}

func openingAboveTheRestingAngleStaysClear() {
    var reference = LidMotionReference()
    hold(&reference, at: 90)
    move(&reference, through: [92, 96, 104])
    let live = reference.reference(clearAngle: 128.3)
    macDuoExpect(live == 90)
    for angle in [90.0, 92, 96, 104, 130, 180] {
        macDuoExpect(FoldMath.progress(angle: angle, clearAngle: live) == 0)
    }
}

func oneDegreeJitterDoesNotMoveTheAnchor() {
    var reference = LidMotionReference()
    hold(&reference, at: 90, jitter: [1, -1, 0, 1, -1, 1])
    macDuoExpect(reference.restingAngle == 90)
    macDuoExpect(reference.reference(clearAngle: 128.3) == 90)
}

func aLaterDwellReAnchorsUpwardAndDownward() {
    var reference = LidMotionReference()
    hold(&reference, at: 90)
    move(&reference, through: [95, 102, 110])
    hold(&reference, at: 110, jitter: [-1, 1])
    macDuoExpect(reference.restingAngle == 110)          // No permanent downward ratchet.
    macDuoExpect(reference.reference(clearAngle: 128.3) == 110)
    move(&reference, through: [102, 88, 70])
    hold(&reference, at: 70)
    macDuoExpect(reference.reference(clearAngle: 128.3) == 70)
}

/// Repeated dwell, re-anchor and move cycles must leave exactly one reference:
/// the angle of the most recent completed dwell.
func repeatedStillnessAndMovementTracksOnlyTheLastRest() {
    var reference = LidMotionReference()
    var expected = 0.0
    for rest in [120.0, 96, 108, 64, 140, 82] {
        move(&reference, through: [rest+9, rest+4, rest+2])
        hold(&reference, at: rest, jitter: [1, -1])
        expected = rest
        macDuoExpect(reference.restingAngle == expected)
        let live = reference.reference(clearAngle: 128.3)
        macDuoExpect(live == min(expected, 128.3))
        // Measured from the live reference, one degree is barely there and
        // further closing keeps building, whatever the rest angle was.
        let small = FoldMath.progress(angle: live-1, clearAngle: live)
        let medium = FoldMath.progress(angle: live-5, clearAngle: live)
        let large = FoldMath.progress(angle: live-15, clearAngle: live)
        macDuoExpect(small < 0.01)
        macDuoExpect(small < medium && medium < large)
    }
}

func aLowRestingAngleIsNotRaisedToTheSettingFloor() {
    var reference = LidMotionReference()
    hold(&reference, at: 45)
    macDuoExpect(reference.reference(clearAngle: 105) == 45)
    macDuoExpect(reference.reference(clearAngle: 60) == 45)
    macDuoExpect(reference.reference(clearAngle: 140) == 45)
    // A lid that came to rest closed still yields a usable reference.
    hold(&reference, at: 45, jitter: [])             // No edge: still 45.
    move(&reference, through: [20, 8])
    hold(&reference, at: 0)
    macDuoExpect(reference.restingAngle == 0)
    macDuoExpect(reference.reference(clearAngle: 105) == 5)
    move(&reference, through: [4])
    hold(&reference, at: 3)
    macDuoExpect(reference.reference(clearAngle: 105) == 5)
}

func aRestingAngleAboveTheSettingCapsAtTheSetting() {
    var reference = LidMotionReference()
    hold(&reference, at: 170)
    macDuoExpect(reference.restingAngle == 170)
    macDuoExpect(reference.reference(clearAngle: 128.3) == 128.3)
    macDuoExpect(reference.reference(clearAngle: 105) == 105)
    macDuoExpect(reference.reference(clearAngle: 200) == 140)
    macDuoExpect(reference.reference(clearAngle: 40) == 60)
    macDuoExpect(reference.reference(clearAngle: .nan) == 105)
    move(&reference, through: [150])
    hold(&reference, at: 141)
    macDuoExpect(reference.reference(clearAngle: 140) == 140)
}

func turningOffClearWhenStillDropsTheReference() {
    var reference = LidMotionReference()
    hold(&reference, at: 90)
    reference.observe(angle: 90, isStill: true, clearWhenStill: false)
    macDuoExpect(reference.restingAngle == nil)
    macDuoExpect(reference.reference(clearAngle: 128.3) == 128.3)
    // Re-enabling while the lid is already still re-anchors at the current angle
    // instead of reviving the cleared edge.
    reference.observe(angle: 111, isStill: true, clearWhenStill: true)
    macDuoExpect(reference.restingAngle == 111)
}

func invalidReadingsAndResetClearTheReferenceAndTheEdge() {
    let invalid: [Double?] = [nil, Double.nan, Double.infinity, -Double.infinity, 181, -1, 200]
    for reading in invalid {
        var reference = LidMotionReference()
        hold(&reference, at: 90)
        reference.observe(angle: reading, isStill: true, clearWhenStill: true)
        macDuoExpect(reference.restingAngle == nil)
        macDuoExpect(reference.reference(clearAngle: 128.3) == 128.3)
        // The cleared edge means the next valid still reading anchors afresh.
        reference.observe(angle: 100, isStill: true, clearWhenStill: true)
        macDuoExpect(reference.restingAngle == 100)
    }
    var reference = LidMotionReference()
    hold(&reference, at: 90)
    reference.reset()
    macDuoExpect(reference.restingAngle == nil)
    macDuoExpect(reference.reference(clearAngle: 105) == 105)
    reference.observe(angle: 90, isStill: true, clearWhenStill: true)
    macDuoExpect(reference.restingAngle == 90)
}

/// Whatever the history, the reference stays inside the documented range and
/// never rises above the user's own clear limit.
func theReferenceStaysFiniteBoundedAndAtMostTheSetting() {
    var reference = LidMotionReference()
    var still = false
    for step in 0...400 {
        let angle = 90+40*sin(Double(step)/7)
        still = step%13 == 0 ? !still : still
        reference.observe(angle: angle, isStill: still, clearWhenStill: true)
        for setting in [60.0, 90, 105, 128.3, 140, .nan, 200] {
            let live = reference.reference(clearAngle: setting)
            let clamped = setting.isFinite ? Swift.min(140, Swift.max(60, setting)) : 105
            macDuoExpect(live.isFinite)
            macDuoExpect(live >= 5 && live <= 140)
            macDuoExpect(live <= clamped)
            if let resting = reference.restingAngle {
                macDuoExpect(live == Swift.max(5, Swift.min(resting, clamped)))
            } else {
                macDuoExpect(live == clamped)
            }
        }
    }
}
