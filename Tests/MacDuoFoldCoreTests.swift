// SPDX-License-Identifier: MIT
// Converted from Mac Duo's Tests/FoldCoreTests/FoldCoreTests.swift
// (github.com/DhananjayBhosale/MacDuo, commit f6862c8), swift-testing -> Vorssaint TestSuite.
// Copyright (c) 2026 Mac Duo contributors, MIT License
// (Sources/Vorssaint/Mantel/LidAnimation/LICENSE-MacDuo.txt). Test bodies unchanged.

import Foundation


func sensorReportsRejectMalformedAndImpossibleValues() {
    macDuoExpect(FoldMath.decodeReport([1,120,0]) == 120)
    macDuoExpect(FoldMath.decodeReport([1,0,0]) == 0)
    macDuoExpect(FoldMath.decodeReport([1,180,0]) == 180)
    macDuoExpect(FoldMath.decodeReport([1,120]) == nil)
    macDuoExpect(FoldMath.decodeReport([2,120,0]) == nil)
    macDuoExpect(FoldMath.decodeReport([1,255,255]) == nil)
}
func desktopIsUnmodifiedAboveClearAngleAndVanishesAtClosed() {
    for clear in stride(from:60.0,through:140.0,by:5) {
        macDuoExpect(FoldMath.progress(angle:clear,clearAngle:clear) == 0)
        macDuoExpect(FoldMath.progress(angle:180,clearAngle:clear) == 0)
        macDuoExpect(FoldMath.progress(angle:5,clearAngle:clear) == 1)
        macDuoExpect(FoldMath.progress(angle:0,clearAngle:clear) == 1)
        var previous = 1.0
        for angle in stride(from:0.0,through:180.0,by:0.5) {
            let next = FoldMath.progress(angle:angle,clearAngle:clear)
            macDuoExpect((0...1).contains(next));macDuoExpect(next <= previous)
            previous = next
        }
    }
}
func smoothingIsFrameRateIndependentAndNeverOvershoots() {
    func simulate(_ fps:Double) -> Double {
        var p = 0.0
        for _ in 0..<Int(fps/10) { p = FoldMath.smooth(current:p,target:1,dt:1/fps) }
        return p
    }
    macDuoExpect(abs(simulate(60)-simulate(120)) < 0.00001)
    var p = 0.0
    for _ in 0..<60 { p = FoldMath.smooth(current:p,target:1,dt:1/60);macDuoExpect((0...1).contains(p)) }
    for _ in 0..<60 { p = FoldMath.smooth(current:p,target:0,dt:1/60);macDuoExpect((0...1).contains(p)) }
    macDuoExpect(p == 0)
}
func invalidNumbersFailOpen() {
    macDuoExpect(FoldMath.progress(angle:.nan,clearAngle:105) == 0)
    macDuoExpect(FoldMath.progress(angle:45,clearAngle:.infinity) == 0)
    macDuoExpect(FoldMath.smooth(current:.nan,target:1,dt:0.1) == 0)
}
