// SPDX-License-Identifier: MIT
// Converted from Mac Duo's Tests/FoldCoreTests/FoldEffectTests.swift
// (github.com/DhananjayBhosale/MacDuo, commit f6862c8), swift-testing -> Vorssaint TestSuite.
// Copyright (c) 2026 Mac Duo contributors, MIT License
// (Sources/Vorssaint/Mantel/LidAnimation/LICENSE-MacDuo.txt). Test bodies unchanged.

import Foundation


func duoIsTheDefaultAndUnknownSelectionsFallBackToIt() {
    macDuoExpect(FoldEffect.fallback == .duo)
    macDuoExpect(FoldEffect.resolve(persisted:nil) == .duo)
    macDuoExpect(FoldEffect.resolve(persisted:"") == .duo)
    macDuoExpect(FoldEffect.resolve(persisted:"Duo") == .duo)          // Identifiers are lower case.
    macDuoExpect(FoldEffect.resolve(persisted:"fold") == .duo)
    macDuoExpect(FoldEffect.resolve(persisted:"kaleidoscope") == .duo)
    macDuoExpect(FoldEffect.resolve(shaderIndex:6) == .duo)
    macDuoExpect(FoldEffect.resolve(shaderIndex:.max) == .duo)
}

func persistedIdentifiersAndShaderIndicesAreStable() {
    macDuoExpect(FoldEffect.allCases.map(\.persistedIdentifier) == ["duo","ghost","roll","shutter","flex","iris"])
    macDuoExpect(FoldEffect.allCases.map(\.shaderIndex) == [0,5,1,2,3,4])
    for effect in FoldEffect.allCases {
        macDuoExpect(FoldEffect.resolve(persisted:effect.persistedIdentifier) == effect)
        macDuoExpect(FoldEffect.resolve(shaderIndex:effect.shaderIndex) == effect)
        macDuoExpect(effect.persistedIdentifier == effect.rawValue)
        macDuoExpect(effect.id == effect.rawValue)
    }
    macDuoExpect(Set(FoldEffect.allCases.map(\.shaderIndex)).count == FoldEffect.allCases.count)
    macDuoExpect(Set(FoldEffect.allCases.map(\.title)).count == FoldEffect.allCases.count)
}

func everyEffectIsPresentableAndFlatEffectsKeepTheSharpPath() {
    macDuoExpect(FoldEffect.allCases.count == 6)
    for effect in FoldEffect.allCases {
        macDuoExpect(!effect.title.isEmpty)
        macDuoExpect(!effect.symbol.isEmpty)
        macDuoExpect(effect.summary.hasSuffix("."))
        macDuoExpect(effect.needsPrefilteredSource == (effect != .duo))
    }
}

/// The angle drives every effect through the same mapping, so a selection can
/// never change when the desktop is untouched or fully closed.
func effectSelectionDoesNotChangeTheAngleContract() {
    for effect in FoldEffect.allCases {
        macDuoExpect(effect.shaderIndex <= 5)
        macDuoExpect(FoldMath.progress(angle:105,clearAngle:105) == 0)
        macDuoExpect(FoldMath.progress(angle:5,clearAngle:105) == 1)
    }
}
