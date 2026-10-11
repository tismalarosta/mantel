// SPDX-License-Identifier: MIT
// Converted from Mac Duo's Tests/FoldCoreTests/FramePacingTests.swift
// (github.com/DhananjayBhosale/MacDuo, commit f6862c8), swift-testing -> Vorssaint TestSuite.
// Copyright (c) 2026 Mac Duo contributors, MIT License
// (Sources/Vorssaint/Mantel/LidAnimation/LICENSE-MacDuo.txt). Test bodies unchanged.

import Foundation


func highRefreshRequiresDisplayPowerAndMotion() {
    macDuoExpect(FoldFramePacing.rate(maximum:120,externalPower:true,lowPower:false,thermalPressure:false,moving:true) == 120)
    macDuoExpect(FoldFramePacing.rate(maximum:60,externalPower:true,lowPower:false,thermalPressure:false,moving:true) == 60)
    macDuoExpect(FoldFramePacing.rate(maximum:120,externalPower:false,lowPower:false,thermalPressure:false,moving:true) == 60)
    macDuoExpect(FoldFramePacing.rate(maximum:120,externalPower:true,lowPower:true,thermalPressure:false,moving:true) == 60)
    macDuoExpect(FoldFramePacing.rate(maximum:120,externalPower:true,lowPower:false,thermalPressure:false,moving:false) == 60)
    macDuoExpect(FoldFramePacing.rate(maximum:120,externalPower:true,lowPower:false,thermalPressure:true,moving:true) == 30)
    macDuoExpect(FoldFramePacing.rate(maximum:48,externalPower:true,lowPower:false,thermalPressure:false,moving:true) == 48)
}

func primingAfterIdlePreservesProgressWithoutJumping() {
    var animation = FoldAnimation()
    _ = animation.sample(target:1,at:0)
    let before = animation.sample(target:1,at:0.03)
    animation.prime(at:5)
    macDuoExpect(animation.sample(target:1,at:5) == before)
    let after = animation.sample(target:1,at:5.008)
    macDuoExpect(after > before && after < 0.7)
}

func sharedSamplesDoNotSpeedUpTheAnimation() {
    var oneView = FoldAnimation(), twoViews = FoldAnimation()
    _ = oneView.sample(target:1,at:0)
    _ = twoViews.sample(target:1,at:0)
    let single = oneView.sample(target:1,at:1.0/60)
    _ = twoViews.sample(target:1,at:1.0/120)
    let shared = twoViews.sample(target:1,at:1.0/60)
    macDuoExpect(abs(single-shared) < 1e-9)
}
