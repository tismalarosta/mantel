// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Carbon.HIToolbox
import Foundation

/// The lid animation's Mantel side: setting ranges, the pause rule, its hub
/// registration, and source contracts that keep the port on Vorssaint's
/// hotkey owner and Mac Duo's fail-open capture. Mac Duo's own core tests run
/// beside these (`MacDuoCoreTests`).
enum LidAnimationTests {
    static func run(_ suite: TestSuite) {
        ranges(suite)
        pausing(suite)
        capture(suite)
        registration(suite)
        sourceContracts(suite)
    }

    private static func ranges(_ suite: TestSuite) {
        typealias Support = LidAnimationSupport
        suite.expect(Support.sanitizedClearAngle(10) == 60 && Support.sanitizedClearAngle(170) == 140
                        && Support.sanitizedClearAngle(.nan) == Support.defaultClearAngle
                        && Support.sanitizedClearAngle(90) == 90,
                     "the start angle stays between 60° and 140°, like Mac Duo's slider")
        suite.expect(Support.sanitizedStillnessDelay(0) == 1 && Support.sanitizedStillnessDelay(9) == 5
                        && Support.sanitizedStillnessDelay(2.6) == 3,
                     "the stillness delay is whole seconds between 1 and 5")
        suite.expect(Support.sanitizedUnit(-1, fallback: 0.5) == 0 && Support.sanitizedUnit(2, fallback: 0.5) == 1
                        && Support.sanitizedUnit(.infinity, fallback: 0.5) == 0.5,
                     "perspective, softness and shadow stay between 0 and 100 %")
        suite.expect(Support.defaultClearAngle == 105 && Support.defaultStillnessDelay == 2
                        && Support.defaultPerspective == 0.7 && Support.defaultSoftness == 0.65
                        && Support.defaultShadow == 0.65,
                     "defaults match Mac Duo's")
        suite.expect(abs(Support.testAngle(at: 0, clearAngle: 105) - 113) < 0.001
                        && abs(Support.testAngle(at: 0.5, clearAngle: 105) - 20) < 0.001
                        && abs(Support.testAngle(at: 1, clearAngle: 105) - 113) < 0.001,
                     "the desktop test sweeps from above the start angle to near shut and back")
    }

    private static func pausing(_ suite: TestSuite) {
        typealias Support = LidAnimationSupport
        suite.expect(!Support.releasesPause(angle: nil, clearAngle: 105),
                     "a missing reading never lifts a pause")
        suite.expect(!Support.releasesPause(angle: 105, clearAngle: 105)
                        && !Support.releasesPause(angle: 109, clearAngle: 105),
                     "jitter around the start angle keeps the pause")
        suite.expect(Support.releasesPause(angle: 110, clearAngle: 105)
                        && Support.releasesPause(angle: 130, clearAngle: 105),
                     "opening the lid clearly past the start angle lifts the pause")
        suite.expect(Support.releasesPause(angle: 145, clearAngle: 400),
                     "the release angle follows the sanitized start angle")
    }

    private static func capture(_ suite: TestSuite) {
        typealias Support = LidAnimationSupport
        suite.expect(Support.shouldCapture(angle: nil, reference: 105, testing: true,
                                           paused: true, clearedForStillness: true),
                     "the desktop test always captures")
        suite.expect(!Support.shouldCapture(angle: 30, reference: 105, testing: false,
                                            paused: true, clearedForStillness: false),
                     "a paused animation captures nothing")
        suite.expect(!Support.shouldCapture(angle: 30, reference: 105, testing: false,
                                            paused: false, clearedForStillness: true),
                     "a still lid captures nothing")
        suite.expect(!Support.shouldCapture(angle: nil, reference: 105, testing: false,
                                            paused: false, clearedForStillness: false),
                     "no reading, no capture")
        suite.expect(!Support.shouldCapture(angle: 119, reference: 105, testing: false,
                                            paused: false, clearedForStillness: false)
                        && Support.shouldCapture(angle: 118.9, reference: 105, testing: false,
                                                 paused: false, clearedForStillness: false),
                     "capture starts 14° before the effect so its first frame is fresh")
    }

    private static func registration(_ suite: TestSuite) {
        let feature = AppFeature.lidAnimation
        suite.expect(!feature.installedByDefault && feature.group == .energyDisplay
                        && feature.permissions == [.screenRecording]
                        && feature.enabledKeys == [DefaultsKey.lidAnimationEnabled],
                     "the lid animation is an opt-in Energy & display feature using Screen Recording")
        let shortcut = GlobalShortcut.lidAnimationPauseDefault
        suite.expect(shortcut.keyCode == Int64(kVK_ANSI_F) && shortcut.modifiers == [.control, .option, .command],
                     "the pause shortcut defaults to Mac Duo's ⌃⌥⌘F")
        let role = GlobalShortcutRole.lidAnimationPause
        suite.expect(role.storageKey == DefaultsKey.lidAnimationPauseShortcut && role.defaultShortcut == shortcut
                        && role.feature == .lidAnimation
                        && role.requiredEnableKeys == [DefaultsKey.lidAnimationEnabled],
                     "the pause shortcut is a recordable role of the lid animation")
        let defaults = Defaults.registeredDefaults
        suite.expect(defaults[DefaultsKey.lidAnimationEnabled] as? Bool == false
                        && defaults[DefaultsKey.lidAnimationEffect] as? String == FoldEffect.fallback.rawValue
                        && defaults[DefaultsKey.lidAnimationClearAngle] as? Double == LidAnimationSupport.defaultClearAngle
                        && defaults[DefaultsKey.lidAnimationClearWhenStill] as? Bool == true
                        && defaults[DefaultsKey.lidAnimationStillnessDelay] as? Double
                            == LidAnimationSupport.defaultStillnessDelay
                        && defaults[DefaultsKey.lidAnimationPerspective] as? Double == LidAnimationSupport.defaultPerspective
                        && defaults[DefaultsKey.lidAnimationSoftness] as? Double == LidAnimationSupport.defaultSoftness
                        && defaults[DefaultsKey.lidAnimationShadow] as? Double == LidAnimationSupport.defaultShadow
                        && defaults[DefaultsKey.lidAnimationPauseShortcut] as? String == shortcut.storageValue,
                     "registered defaults match the support defaults")
        suite.expect(FoldEffect.allCases.map(\.rawValue) == ["duo", "ghost", "roll", "shutter", "flex", "iris"],
                     "all six Mac Duo effects are offered, ids unchanged")
        for language in AppLanguage.allCases {
            let text = FeatureStrings.lidAnimation(language)
            suite.expect(FoldEffect.allCases.allSatisfy { !text.summary(for: $0).isEmpty }
                            && text.clearAfterFormat.contains("%d")
                            && text.statusCaptureFailedFormat.contains("%@"),
                         "the lid animation has complete strings in \(language.rawValue)")
        }
    }

    private static func sourceContracts(_ suite: TestSuite) {
        let folder = "Sources/Vorssaint/Mantel/LidAnimation/"
        func source(_ name: String) -> String {
            (try? String(contentsOfFile: folder + name, encoding: .utf8)) ?? ""
        }
        let service = source("LidAnimationService.swift")
        suite.expect(!service.isEmpty, "the lid animation service source is readable")
        let mantelSources = ["LidAnimationService.swift", "LidSensor.swift", "LidDesktopCapture.swift",
                             "FoldRenderer.swift", "LidAnimationSettingsCard.swift"].map(source).joined()
        suite.expect(!mantelSources.contains("RegisterEventHotKey") && !mantelSources.contains("InstallEventHandler")
                        && !mantelSources.contains("addLocalMonitorForEvents"),
                     "Esc and the pause shortcut go through QuickToolHotkey, not a second Carbon handler")
        suite.expect(service.contains("QuickToolHotkey(id: 2601)") && service.contains("QuickToolHotkey(id: 2602)"),
                     "the lid hotkeys sit next to Type Clipboard's id, far from Vorssaint's")
        suite.expect(service.contains("guard registerEscape() else"),
                     "nothing covers the desktop unless Esc can stop it")
        suite.expect(service.contains("panel.sharingType = .none")
                        && service.contains("panel.ignoresMouseEvents = true"),
                     "the overlay is never captured itself and never takes a click")
        suite.expect(service.contains("if now - sensorAt > 1"),
                     "a second without a sensor reading clears the desktop")
        let capture = source("LidDesktopCapture.swift")
        suite.expect(capture.contains("excludingApplications:[ownApplication]")
                        && capture.contains("config.capturesAudio = false"),
                     "the desktop stream excludes Mantel itself and records no audio")
        for name in ["Core/FoldEffect.swift", "Core/FoldMath.swift", "Core/FoldVisualAnimation.swift",
                     "Core/LidMotionReference.swift", "Core/LidStillness.swift", "LidSensor.swift",
                     "LidDesktopCapture.swift", "FoldRenderer.swift", "FoldShader.swift",
                     "LidAnimationService.swift"] {
            suite.expect(source(name).contains("Mac Duo contributors, MIT License"),
                         "\(name) keeps Mac Duo's MIT notice")
        }
        suite.expect(source("LICENSE-MacDuo.txt").contains("Permission is hereby granted"),
                     "Mac Duo's licence text ships beside the port")
    }
}
