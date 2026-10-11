// SPDX-License-Identifier: MIT
// Converted from Mac Duo's Tests/FoldCoreTests/LidStillnessTests.swift
// (github.com/DhananjayBhosale/MacDuo, commit f6862c8), swift-testing -> Vorssaint TestSuite.
// Copyright (c) 2026 Mac Duo contributors, MIT License
// (Sources/Vorssaint/Mantel/LidAnimation/LICENSE-MacDuo.txt). Test bodies unchanged.

import Foundation


func aHeldAngleClearsOnlyAfterTwoSeconds() {
    for angle in [20.0,90,100,118,140] {
        var detector = LidStillness()
        for tick in 0..<60 {
            detector.observe(angle:angle,at:Double(tick)/30)
            macDuoExpect(!detector.isStill)
        }
        detector.observe(angle:angle,at:2)
        macDuoExpect(detector.isStill)
        detector.observe(angle:angle,at:2.5)
        macDuoExpect(detector.isStill)
    }
}

func sharedLiveAnimationClearsAtNinetyDegreesAndResumes(seconds: Int) {
    var detector = LidStillness()
    var animation = FoldAnimation()
    let moving = FoldMath.progress(angle:90,clearAngle:105)
    macDuoExpect(moving > 0 && moving < 0.1)
    for tick in 0...((seconds+1)*120) {
        let time = Double(tick)/120
        if tick%4 == 0 { detector.observe(angle:90,at:time,delay:Double(seconds)) }
        let target = detector.isStill ? 0 : moving
        let desktop = animation.sample(target:target,at:time)
        let preview = animation.sample(target:target,at:time)
        macDuoExpect(desktop == preview)
        if time >= 0.4 && time < Double(seconds) { macDuoExpect(desktop > moving*0.99) }
        if time > Double(seconds)+0.5 { macDuoExpect(desktop == 0) }
    }
    let now = Double(seconds+1)
    detector.observe(angle:88,at:now+0.01,delay:Double(seconds))
    macDuoExpect(!detector.isStill)
    let resuming = animation.sample(target:FoldMath.progress(angle:88,clearAngle:105),at:now+0.01)
    macDuoExpect(resuming > 0 && resuming < FoldMath.progress(angle:88,clearAngle:105))
}

func movementStartsANewDwellAndResumesFromRest() {
    var detector = LidStillness()
    for tick in 0...60 { detector.observe(angle:118,at:Double(tick)/30) }
    macDuoExpect(detector.isStill)
    detector.observe(angle:100,at:2.1)
    macDuoExpect(!detector.isStill)
    for tick in 1..<60 {
        detector.observe(angle:100,at:2.1+Double(tick)/30)
        macDuoExpect(!detector.isStill)
    }
    detector.observe(angle:100,at:4.11)
    macDuoExpect(detector.isStill)
    detector.observe(angle:102,at:4.2)
    macDuoExpect(!detector.isStill)
}

func oneDegreeJitterDoesNotRestartTheEffect() {
    var detector = LidStillness()
    for tick in 0...60 { detector.observe(angle:100,at:Double(tick)/30) }
    for tick in 61...180 {
        detector.observe(angle:100+Double(tick%3-1),at:Double(tick)/30)
        macDuoExpect(detector.isStill)
    }
    detector.observe(angle:98,at:6.1)
    macDuoExpect(!detector.isStill)
}

func slowMotionAccumulatesInsteadOfLookingStationary() {
    var detector = LidStillness()
    for tick in 0...300 {
        detector.observe(angle:118-Double(tick/15),at:Double(tick)/30)
        macDuoExpect(!detector.isStill)
    }
}

func sensorGapsInvalidReadingsAndResetRequireAFreshDwell() {
    var detector = LidStillness()
    for tick in 0...60 { detector.observe(angle:100,at:Double(tick)/30) }
    for (angle,time): (Double?,Double) in [(100,4),(100,3),(nil,3.1),(.nan,3.2),(181,3.3),(100,.infinity)] {
        detector.observe(angle:angle,at:time)
        macDuoExpect(!detector.isStill)
    }
    for tick in 0...60 { detector.observe(angle:100,at:5+Double(tick)/30) }
    macDuoExpect(detector.isStill)
    detector.reset()
    detector.observe(angle:100,at:7.1)
    macDuoExpect(!detector.isStill)
}

func selectedDelayControlsWhenTheDisplayClears(seconds: Int) {
    var detector = LidStillness()
    for tick in 0..<(seconds*30) {
        detector.observe(angle:100,at:Double(tick)/30,delay:Double(seconds))
        macDuoExpect(!detector.isStill)
    }
    detector.observe(angle:100,at:Double(seconds),delay:Double(seconds))
    macDuoExpect(detector.isStill)
}

func changingTheDelayDoesNotReblurAnAlreadyClearDisplay() {
    var detector = LidStillness()
    for tick in 0...30 { detector.observe(angle:100,at:Double(tick)/30,delay:1) }
    macDuoExpect(detector.isStill)
    detector.observe(angle:100,at:1.1,delay:5)
    macDuoExpect(detector.isStill)
    detector.observe(angle:102,at:1.2,delay:5)
    macDuoExpect(!detector.isStill)
    for tick in 1..<150 {
        detector.observe(angle:102,at:1.2+Double(tick)/30,delay:5)
        macDuoExpect(!detector.isStill)
    }
    detector.observe(angle:102,at:6.21,delay:5)
    macDuoExpect(detector.isStill)
}
