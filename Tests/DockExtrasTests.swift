// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import CoreGraphics
import Foundation

/// Mantel's DockDoor extras, batches 1 (C2, C5, C6, C7) and 2 (C3, C4, C8): the pure decisions,
/// the hub registration, "nothing changes while off", and source contracts
/// keeping them on Vorssaint's Dock tap, window helpers and mixer.
enum DockExtrasTests {
    static func run(_ suite: TestSuite) {
        quitClick(suite)
        scroll(suite)
        swipe(suite)
        shake(suite)
        titleBar(suite)
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
            (.dockPreviewSwipe, DefaultsKey.dockPreviewSwipeEnabled),
            (.dockPreviewShake, DefaultsKey.dockPreviewShakeEnabled),
            (.titleBarScroll, DefaultsKey.titleBarScrollEnabled),
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
        suite.expect(AppFeature.titleBarScroll.energyProfile == .mouse
                        && AppFeature.dockPreviewSwipe.energyProfile == .idle
                        && AppFeature.dockPreviewShake.energyProfile == .idle,
                     "title bar scrolling rides the scroll tap; swipe and shake only watch the panel")
        for language in AppLanguage.allCases {
            let text = FeatureStrings.dockExtras(language)
            suite.expect(![text.quitClickTitle, text.scrollTitle, text.massActionsTitle, text.windowButtonsTitle,
                           text.closeAll, text.minimizeAll, text.fullScreen, text.quit, text.forceQuit,
                           text.swipeTitle, text.swipeHub, text.swipeCaption, text.shakeTitle, text.shakeHub,
                           text.shakeCaption, text.titleBarTitle, text.titleBarHub, text.titleBarCaption]
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
            (.dockPreviewSwipe, DefaultsKey.dockPreviewSwipeEnabled),
            (.dockPreviewShake, DefaultsKey.dockPreviewShakeEnabled),
            (.titleBarScroll, DefaultsKey.titleBarScrollEnabled),
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
        let titleBar = source("Sources/Vorssaint/Mantel/DockExtras/DockExtrasTitleBarScroll.swift")
        let swipe = source("Sources/Vorssaint/Mantel/DockExtras/DockPreviewSwipe.swift")
        let shake = source("Sources/Vorssaint/Mantel/DockExtras/DockPreviewShake.swift")
        suite.expect(![tap, buttons, titleBar, swipe, shake].contains(where: \.isEmpty),
                     "the Dock extras sources are readable")
        let mantel = tap + buttons + titleBar + swipe + shake
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
                        && dockClick.contains("if DockExtrasSupport.wantsScrollEvents"),
                     "the Dock Click tap hosts the extras, listens to scrolls only for them, "
                        + "and keeps its own clicks behind their own switches")
        suite.expect(tap.contains("DockExtrasTitleBarScroll.shared.handle(")
                        && titleBar.contains("WindowLayoutService.shared")
                        && titleBar.contains("apply(.maximize)") && titleBar.contains("apply(.center)")
                        && titleBar.contains("apply(.restore)"),
                     "title bar scrolls ride the Dock tap and move windows through Vorssaint's Window Layout")
        suite.expect(swipe.contains("addLocalMonitorForEvents") && swipe.contains("apply(.maximize)")
                        && swipe.contains("NSEvent.removeMonitor"),
                     "preview swipes watch only this app's scrolls, maximize through Window Layout, "
                        + "and drop the watcher when switched off")
        let panel = source("Sources/Vorssaint/UI/Switcher/DockPreviewPanelView.swift")
        let service = source("Sources/Vorssaint/Services/DockPreview/DockPreviewService.swift")
        suite.expect(panel.contains("DockPreviewSwipeModifier(")
                        && service.contains("DockPreviewShake.shared.begin(item)")
                        && service.contains("DockPreviewShake.shared.shaken(at:")
                        && shake.contains("WindowActivator.setWindowMinimized"),
                     "swipe and shake hook into Vorssaint's own preview cards and drag to place")
        suite.expect(!DockPreviewSupport.showsPanelHeader(isPinned: false)
                        && DockPreviewSupport.showsPanelHeader(isPinned: true),
                     "without Close All installed, a hovered preview keeps Vorssaint's headerless look")
    }

    private static func swipe(_ suite: TestSuite) {
        typealias Support = DockExtrasSupport
        suite.expect(Support.swipeDirection(totalX: 0, totalY: 80, natural: false) == .up
                        && Support.swipeDirection(totalX: 0, totalY: -80, natural: true) == .up
                        && Support.swipeDirection(totalX: 0, totalY: -80, natural: false) == .down,
                     "an upward swipe reads as up with either scrolling direction")
        suite.expect(Support.swipeDirection(totalX: 80, totalY: 0, natural: true) == .right
                        && Support.swipeDirection(totalX: -80, totalY: 0, natural: false) == .right
                        && Support.swipeDirection(totalX: -80, totalY: 0, natural: true) == .left,
                     "sideways swipes are normalized too, for a Dock on the side")
        suite.expect(Support.swipeDirection(totalX: 0, totalY: 40, natural: false) == nil
                        && Support.swipeDirection(totalX: 60, totalY: 60, natural: false) == nil
                        && Support.swipeDirection(totalX: .nan, totalY: 90, natural: false) == nil,
                     "short, diagonal or broken swipes do nothing (DockDoor's 50 pt threshold)")
        suite.expect(Support.swipeAction(.down, dock: .bottom) == .minimize
                        && Support.swipeAction(.up, dock: .bottom) == .maximize
                        && Support.swipeAction(.left, dock: .bottom) == .none,
                     "Dock at the bottom: down minimizes, up maximizes, sideways does nothing")
        suite.expect(Support.swipeAction(.left, dock: .left) == .minimize
                        && Support.swipeAction(.right, dock: .left) == .maximize
                        && Support.swipeAction(.right, dock: .right) == .minimize
                        && Support.swipeAction(.left, dock: .right) == .maximize
                        && Support.swipeAction(.up, dock: .left) == .none
                        && Support.swipeAction(nil, dock: .bottom) == .none,
                     "Dock on a side: toward it minimizes, away maximizes")
    }

    private static func shake(_ suite: TestSuite) {
        let zigzag = (0..<10).map { CGPoint(x: $0 % 2 == 0 ? 0 : 30, y: 0) }
        suite.expect(DockExtrasSupport.isShake(zigzag), "a quick back-and-forth is a shake")
        suite.expect(!DockExtrasSupport.isShake(Array(zigzag.prefix(7))), "fewer than 8 samples is not yet a shake")
        let straight = (0..<12).map { CGPoint(x: CGFloat($0) * 40, y: 0) }
        suite.expect(!DockExtrasSupport.isShake(straight), "a straight drag is not a shake")
        let jitter = (0..<12).map { CGPoint(x: $0 % 2 == 0 ? 0 : 4, y: 0) }
        suite.expect(!DockExtrasSupport.isShake(jitter), "a trembling hand is not a shake (5 pt and 100 pt floors)")
    }

    private static func titleBar(_ suite: TestSuite) {
        typealias Support = DockExtrasSupport
        func decide(_ dx: Double, _ dy: Double, natural: Bool = false, momentum: Bool = false,
                    since: TimeInterval = 1) -> Support.TitleBarDecision {
            Support.titleBarDecision(deltaX: dx, deltaY: dy, natural: natural, isMomentum: momentum,
                                     sinceLastAction: since)
        }
        suite.expect(decide(0, 2) == .maximize && decide(0, -2) == .centre
                        && decide(0, -2, natural: true) == .maximize,
                     "scrolling up maximizes, down centres, with either scrolling direction")
        suite.expect(decide(3, 1) == .pass, "sideways scrolls go on to the app (desktop switching dropped)")
        suite.expect(decide(0, 0.1) == .pass && decide(0, 2, momentum: true) == .pass
                        && decide(.nan, 2) == .pass,
                     "noise, momentum and broken deltas go on to the app")
        suite.expect(decide(0, 2, since: 0.2) == .swallow && decide(0, 2, since: 0.35) == .maximize,
                     "one action per 0.35 s; the scrolls in between stay away from the app")
        let window = CGRect(x: 100, y: 50, width: 800, height: 600)
        suite.expect(Support.titleBarRect(window: window, closeButton: CGRect(x: 108, y: 56, width: 14, height: 14))
                        == CGRect(x: 100, y: 50, width: 800, height: 48)
                        && Support.titleBarRect(window: window, closeButton: CGRect(x: 108, y: 80, width: 14, height: 14))
                        .height == 56
                        && Support.titleBarRect(window: window, closeButton: CGRect(x: 108, y: 140, width: 14, height: 14))
                        .height == 72,
                     "the title bar runs to 12 pt below the close button, between 48 and 72 pt")
        let visible = CGRect(x: 0, y: 33, width: 1512, height: 900)
        suite.expect(Support.fills(CGRect(x: 2, y: 35, width: 1508, height: 897), visibleFrame: visible)
                        && !Support.fills(window, visibleFrame: visible),
                     "a window already filling the screen is told apart, so it has nothing to restore")
        suite.expect(Support.topLeftRect(fromAppKit: CGRect(x: 0, y: 0, width: 1512, height: 900),
                                         primaryScreenHeight: 982) == CGRect(x: 0, y: 82, width: 1512, height: 900),
                     "screen areas convert to the top-left coordinates windows use")
    }
}
