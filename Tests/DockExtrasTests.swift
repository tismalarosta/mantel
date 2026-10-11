// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// Mantel's DockDoor extras, batch 1 (C2, C5, C6, C7): the pure decisions,
/// the hub registration, "nothing changes while off", and source contracts
/// keeping them on Vorssaint's Dock tap, window helpers and mixer.
enum DockExtrasTests {
    static func run(_ suite: TestSuite) {
        quitClick(suite)
        scroll(suite)
        registration(suite)
        offMeansOff(suite)
        sourceContracts(suite)
    }

    private static func quitClick(_ suite: TestSuite) {
        typealias Support = DockExtrasSupport
        suite.expect(Support.quitIntent(command: true, option: false, control: false, shift: false) == .quit,
                     "⌘ right-click quits")
        suite.expect(Support.quitIntent(command: true, option: true, control: false, shift: false) == .forceQuit,
                     "⌥⌘ right-click force-quits")
        suite.expect(Support.quitIntent(command: false, option: true, control: false, shift: false) == .none
                        && Support.quitIntent(command: true, option: false, control: true, shift: false) == .none
                        && Support.quitIntent(command: true, option: false, control: false, shift: true) == .none,
                     "any other right-click keeps the Dock's own menu")
        suite.expect(!Support.canQuit(bundleID: "com.apple.finder", isOwnApp: false)
                        && !Support.canQuit(bundleID: "com.example.app", isOwnApp: true)
                        && Support.canQuit(bundleID: "com.example.app", isOwnApp: false)
                        && Support.canQuit(bundleID: nil, isOwnApp: false),
                     "Finder and Mantel itself are never quit from the Dock")
    }

    private static func scroll(_ suite: TestSuite) {
        typealias Support = DockExtrasSupport
        func action(_ delta: Double, natural: Bool = false, media: Bool = false, volume: Bool = true,
                    since: TimeInterval = 1) -> Support.ScrollAction {
            Support.scrollAction(deltaY: delta, naturalScrolling: natural, isMediaApp: media,
                                 mediaVolume: volume, sinceLastAction: since)
        }
        suite.expect(action(2) == .show && action(-2) == .hide, "scrolling up shows the app, down hides it")
        suite.expect(action(-2, natural: true) == .show && action(2, natural: true) == .hide,
                     "natural scrolling is normalized so the gesture means the same on every Mac")
        suite.expect(action(0.05) == .none && action(.nan) == .none, "tiny or broken deltas are noise")
        suite.expect(action(2, since: 0.1) == .none && action(2, since: 0.3) == .show,
                     "one show or hide per 0.3 s, DockDoor's debounce")
        func volume(_ result: Support.ScrollAction, _ expected: Double) -> Bool {
            if case .volume(let change) = result { return abs(change - expected) < 0.0001 }
            return false
        }
        suite.expect(volume(action(2, media: true), 0.03) && volume(action(-2, media: true), -0.03),
                     "on Spotify and Music the scroll turns the volume")
        suite.expect(action(2, media: true, volume: false) == .show,
                     "with media volume off, music apps scroll like any other")
        suite.expect(volume(action(2, media: true, since: 0.01), 0.03),
                     "volume follows every scroll, without the debounce")
        suite.expect(Support.nextVolume(current: 0.99, change: 0.03) == 1
                        && Support.nextVolume(current: 0.01, change: -0.03) == 0
                        && abs(Support.nextVolume(current: 0.5, change: 0.03) - 0.53) < 0.0001,
                     "the volume stays between 0 and 100 %")
    }

    private static func registration(_ suite: TestSuite) {
        let extras: [(AppFeature, String)] = [
            (.dockQuitClick, DefaultsKey.dockQuitClickEnabled),
            (.dockScroll, DefaultsKey.dockScrollEnabled),
            (.dockPreviewMassActions, DefaultsKey.dockPreviewMassActionsEnabled),
            (.dockPreviewWindowButtons, DefaultsKey.dockPreviewWindowButtonsEnabled),
        ]
        for (feature, key) in extras {
            suite.expect(!feature.installedByDefault && feature.group == .windowsDock
                            && feature.permissions == [.accessibility] && feature.enabledKeys == [key]
                            && Defaults.registeredDefaults[key] as? Bool == true,
                         "\(feature.rawValue) is its own opt-in Windows & Dock switch, on once installed")
        }
        suite.expect(AppFeature.dockQuitClick.energyProfile == .mouse && AppFeature.dockScroll.energyProfile == .mouse
                        && AppFeature.dockPreviewMassActions.energyProfile == .idle
                        && AppFeature.dockPreviewWindowButtons.energyProfile == .idle,
                     "the input extras are labelled as mouse taps, the preview buttons as idle")
        for language in AppLanguage.allCases {
            let text = FeatureStrings.dockExtras(language)
            suite.expect(![text.quitClickTitle, text.scrollTitle, text.massActionsTitle, text.windowButtonsTitle,
                           text.closeAll, text.minimizeAll, text.fullScreen, text.quit, text.forceQuit]
                            .contains(where: \.isEmpty),
                         "the Dock extras have complete strings in \(language.rawValue)")
        }
    }

    /// SPEC: "nothing changes with it off". An empty defaults suite stands
    /// for a Mac where none of the extras is installed.
    private static func offMeansOff(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.dock-extras.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "a scratch defaults suite is available")
            return
        }
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.register(defaults: AppFeature.availabilityDefaults)
        defaults.register(defaults: Defaults.registeredDefaults)
        let features: [(AppFeature, String)] = [
            (.dockQuitClick, DefaultsKey.dockQuitClickEnabled), (.dockScroll, DefaultsKey.dockScrollEnabled),
            (.dockPreviewMassActions, DefaultsKey.dockPreviewMassActionsEnabled),
            (.dockPreviewWindowButtons, DefaultsKey.dockPreviewWindowButtonsEnabled),
        ]
        suite.expect(features.allSatisfy { !DockExtrasSupport.isOn($0.0, key: $0.1, in: defaults) },
                     "an update installs none of the extras")
        defaults.set(true, forKey: AppFeature.dockScroll.availabilityKey)
        suite.expect(DockExtrasSupport.isOn(.dockScroll, key: DefaultsKey.dockScrollEnabled, in: defaults),
                     "installing an extra turns it on")
        defaults.set(false, forKey: DefaultsKey.dockScrollEnabled)
        suite.expect(!DockExtrasSupport.isOn(.dockScroll, key: DefaultsKey.dockScrollEnabled, in: defaults),
                     "its own switch turns it off again")
    }

    private static func sourceContracts(_ suite: TestSuite) {
        func source(_ path: String) -> String {
            (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        }
        let tap = source("Sources/Vorssaint/Mantel/DockExtras/DockExtrasTap.swift")
        let buttons = source("Sources/Vorssaint/Mantel/DockExtras/DockPreviewExtraButtons.swift")
        suite.expect(!tap.isEmpty && !buttons.isEmpty, "the Dock extras sources are readable")
        let mantel = tap + buttons
        suite.expect(!mantel.contains("tapCreate") && !mantel.contains("addGlobalMonitorForEvents"),
                     "the extras add no event tap or monitor of their own (SPEC rule 4)")
        suite.expect(tap.contains("AppVolumeMixer.setSystemOutputVolume")
                        && !tap.contains("AudioObjectSetPropertyData"),
                     "Dock scroll volume goes through Vorssaint's mixer")
        suite.expect(buttons.contains("WindowActivator.setWindowMinimized")
                        && buttons.contains("WindowActivator.closeWindow(")
                        && buttons.contains("WindowActivator.toggleFullScreen"),
                     "window actions reuse Vorssaint's WindowActivator")
        let dockClick = source("Sources/Vorssaint/Services/DockClick/DockClickService.swift")
        suite.expect(dockClick.contains("DockExtrasTap.shared.handle(")
                        && dockClick.contains("guard clickActionsWanted else")
                        && dockClick.contains("if DockExtrasSupport.scrollOn"),
                     "the Dock Click tap hosts the extras, listens to scrolls only for them, "
                        + "and keeps its own clicks behind their own switches")
        suite.expect(!DockPreviewSupport.showsPanelHeader(isPinned: false)
                        && DockPreviewSupport.showsPanelHeader(isPinned: true),
                     "without Close All installed, a hovered preview keeps Vorssaint's headerless look")
    }
}
