// SPDX-License-Identifier: MIT
// Converted from Mac Duo's Tests/FoldCoreTests/*.swift
// (github.com/DhananjayBhosale/MacDuo, commit f6862c8), swift-testing -> Vorssaint TestSuite.
// Copyright (c) 2026 Mac Duo contributors, MIT License
// (Sources/Vorssaint/Mantel/LidAnimation/LICENSE-MacDuo.txt). Test bodies unchanged.

import Foundation

/// The suite Mac Duo's converted checks report into.
nonisolated(unsafe) var macDuoSuite: TestSuite?

func macDuoExpect(_ condition: @autoclosure () -> Bool, function: String = #function,
                  file: String = #fileID, line: Int = #line) {
    macDuoSuite?.expect(condition(), "Mac Duo core: \(function) (\(file):\(line))")
}

/// Every test from Mac Duo's FoldCoreTests except the self-updater's.
enum MacDuoCoreTests {
    static func run(_ suite: TestSuite) {
        macDuoSuite = suite
        defer { macDuoSuite = nil }
        sensorReportsRejectMalformedAndImpossibleValues()
        desktopIsUnmodifiedAboveClearAngleAndVanishesAtClosed()
        smoothingIsFrameRateIndependentAndNeverOvershoots()
        invalidNumbersFailOpen()
        duoIsTheDefaultAndUnknownSelectionsFallBackToIt()
        persistedIdentifiersAndShaderIndicesAreStable()
        everyEffectIsPresentableAndFlatEffectsKeepTheSharpPath()
        effectSelectionDoesNotChangeTheAngleContract()
        physicalDefocusIsGentleAtOnsetAndConsistentAcrossRestingAngles()
        lowRestingAnglesDoNotTurnTinyMovementsIntoBlackouts()
        everyReachableRestingAngleHasABoundedPerDegreeBlurChange()
        clearIsFiniteMonotonicAndCrossfadesOnlyNearTheEnd()
        interruptedReturnRetargetsFromTheCurrentVisualState()
        sharedVisualClockMatchesAtThirtySixtyAndOneTwentyHz()
        physicalTiltUsesDegreesRatherThanEasedProgressAndClearsWithBlur()
        counterRotationTracksMovingLidWithinOneDegreeWithoutOvershoot()
        quantizedLidStepsProduceEvenGhostMotionWithoutAddedLag()
        slowQuantizedLidSweepDoesNotJumpAVisibleDegreeAtOnce()
        quantizedLidMotionToleratesSensorEdgesThatSlipAcrossFrames()
        interruptedClearDiscardsIncomingTiltVelocity()
        restingPlaneStaysPairedWithTiltThroughClearAndInterruptedMotion()
        planeMetadataDoesNotMakeAnInvisibleFrameVisibleAndRejectsInvalidValues()
        for value in 1...5 { selectedDwellFinishesBeforeTheVisualReturnStarts(seconds: value) }
        highRefreshRequiresDisplayPowerAndMotion()
        primingAfterIdlePreservesProgressWithoutJumping()
        sharedSamplesDoNotSpeedUpTheAnimation()
        withoutARestingAngleTheSavedSettingIsTheReference()
        aMoveAfterTheDwellIsMeasuredFromTheRestingAngle()
        openingAboveTheRestingAngleStaysClear()
        oneDegreeJitterDoesNotMoveTheAnchor()
        aLaterDwellReAnchorsUpwardAndDownward()
        repeatedStillnessAndMovementTracksOnlyTheLastRest()
        aLowRestingAngleIsNotRaisedToTheSettingFloor()
        aRestingAngleAboveTheSettingCapsAtTheSetting()
        turningOffClearWhenStillDropsTheReference()
        invalidReadingsAndResetClearTheReferenceAndTheEdge()
        theReferenceStaysFiniteBoundedAndAtMostTheSetting()
        aHeldAngleClearsOnlyAfterTwoSeconds()
        movementStartsANewDwellAndResumesFromRest()
        oneDegreeJitterDoesNotRestartTheEffect()
        slowMotionAccumulatesInsteadOfLookingStationary()
        sensorGapsInvalidReadingsAndResetRequireAFreshDwell()
        changingTheDelayDoesNotReblurAnAlreadyClearDisplay()
        for value in 1...5 { sharedLiveAnimationClearsAtNinetyDegreesAndResumes(seconds: value) }
        for value in 1...5 { selectedDelayControlsWhenTheDisplayClears(seconds: value) }
    }
}
