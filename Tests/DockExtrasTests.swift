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
        switcherSwipe(suite)
        indicator(suite)
        dockLock(suite)
        folders(suite)
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
            (.trackpadSwitcherSwipe, DefaultsKey.trackpadSwitcherSwipeEnabled),
            (.dockActiveIndicator, DefaultsKey.dockActiveIndicatorEnabled),
            (.dockLock, DefaultsKey.dockLockEnabled),
            (.dockAppCards, DefaultsKey.dockAppCardsEnabled),
            (.dockFolderPop, DefaultsKey.dockFolderPopEnabled),
            (.dockLivePreviews, DefaultsKey.dockLivePreviewsEnabled),
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
        suite.expect(AppFeature.trackpadSwitcherSwipe.energyProfile == .mouse
                        && AppFeature.dockLock.energyProfile == .mouse
                        && AppFeature.dockActiveIndicator.energyProfile == .periodic,
                     "the swipe and the Dock lock are input taps; the indicator looks at the Dock on a timer")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.titleBarScrollSwitchesDesktop] as? Bool == false
                        && Defaults.registeredDefaults[DefaultsKey.trackpadSwitcherSwipeFingers] as? Int == 3
                        && Defaults.registeredDefaults[DefaultsKey.dockActiveIndicatorStyle] as? String == "line"
                        && Defaults.registeredDefaults[DefaultsKey.dockLockScreen] as? String == "",
                     "desktop switching stays off for existing title bar users; 3 fingers, a line, the menu bar screen")
        for language in AppLanguage.allCases {
            let text = FeatureStrings.dockExtras(language)
            suite.expect(![text.quitClickTitle, text.scrollTitle, text.massActionsTitle, text.windowButtonsTitle,
                           text.closeAll, text.minimizeAll, text.fullScreen, text.quit, text.forceQuit,
                           text.swipeTitle, text.swipeHub, text.swipeCaption, text.shakeTitle, text.shakeHub,
                           text.shakeCaption, text.titleBarTitle, text.titleBarHub, text.titleBarCaption,
                           text.switcherSwipeTitle, text.switcherSwipeHub, text.switcherSwipeCaption,
                           text.switcherNeeded, text.indicatorTitle, text.indicatorHub, text.indicatorCaption,
                           text.styleLine, text.styleDots, text.dockLockTitle, text.dockLockHub,
                           text.dockLockCaption, text.menuBarScreen, text.titleBarDesktop,
                           text.titleBarDesktopCaption, text.appCardsTitle, text.appCardsHub,
                           text.appCardsCaption, text.nothingToday, text.allDay,
                           text.folderPopTitle, text.folderPopHub, text.folderPopCaption, text.openInFinder,
                           text.folderEmpty, text.livePreviewsTitle, text.livePreviewsHub,
                           text.livePreviewsCaption, text.livePreviewsRate]
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
            (.trackpadSwitcherSwipe, DefaultsKey.trackpadSwitcherSwipeEnabled),
            (.dockActiveIndicator, DefaultsKey.dockActiveIndicatorEnabled),
            (.dockLock, DefaultsKey.dockLockEnabled),
            (.dockAppCards, DefaultsKey.dockAppCardsEnabled),
            (.dockFolderPop, DefaultsKey.dockFolderPopEnabled),
            (.dockLivePreviews, DefaultsKey.dockLivePreviewsEnabled),
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
        let switcherSwipe = source("Sources/Vorssaint/Mantel/DockExtras/TrackpadSwitcherSwipe.swift")
        let indicator = source("Sources/Vorssaint/Mantel/DockExtras/DockActiveIndicator.swift")
        let lock = source("Sources/Vorssaint/Mantel/DockExtras/DockLock.swift")
        let card = source("Sources/Vorssaint/Mantel/DockExtras/DockAppCard.swift")
        suite.expect(!card.isEmpty && card.contains("NotchMusicService.shared") && card.contains("NotchCalendarService.shared")
                        && !card.contains("tapCreate") && !card.contains("mediaremote"),
                     "the Dock cards read Vorssaint's music and calendar services, no second source")
        suite.expect(source("Sources/Vorssaint/Services/DockPreview/DockPreviewService.swift")
                        .contains("DockAppCard.shared.show(for: hit.app"),
                     "the card is offered where the Dock preview opens")
        suite.expect(AppFeature.dockAppCards.energyProfile == .idle
                        && DockExtrasSupport.mediaBundleIDs.contains("com.github.th-ch.youtube-music"),
                     "the cards cost nothing at rest; YouTube Music counts as a music app")
        let previewService = source("Sources/Vorssaint/Services/DockPreview/DockPreviewService.swift")
        let live = source("Sources/Vorssaint/Mantel/DockExtras/DockPreviewLive.swift")
        let folderPop = source("Sources/Vorssaint/Mantel/DockExtras/DockFolderPop.swift")
        suite.expect(previewService.contains("DockFolderPop.shared.pointerMoved(at: axPoint)")
                        && previewService.contains("DockPreviewLive.shared.begin()")
                        && live.contains("service.refreshVisiblePreviews()")
                        && !live.contains("SCStream") && !folderPop.contains("tapCreate"),
                     "folders and live previews ride on Vorssaint's Dock preview and its one capture path")
        suite.expect(AppFeature.dockLivePreviews.energyProfile == .periodic
                        && AppFeature.dockFolderPop.energyProfile == .idle
                        && DockExtrasSupport.sanitizedLiveFPS(10) == 10 && DockExtrasSupport.sanitizedLiveFPS(60) == 5
                        && Defaults.registeredDefaults[DefaultsKey.dockLivePreviewFPS] as? Int == 5,
                     "live previews are labelled as periodic, 2, 5 or 10 frames a second, 5 by default")
        suite.expect(![tap, buttons, titleBar, swipe, shake, switcherSwipe, indicator, lock].contains(where: \.isEmpty),
                     "the Dock extras sources are readable")
        let mantel = tap + buttons + titleBar + swipe + shake + indicator + lock
        suite.expect(switcherSwipe.components(separatedBy: "tapCreate").count == 2
                        && switcherSwipe.contains("options: .listenOnly")
                        && switcherSwipe.contains("AppFeature.switcher.isAvailable")
                        && switcherSwipe.contains("DefaultsKey.switcherShortcut"),
                     "the switcher swipe only listens, and drives Vorssaint's own switcher by its shortcut")
        suite.expect(titleBar.contains("SpaceWindowBridge.pressSpaceShortcut"),
                     "sideways title bar scrolls change desktop the way Vorssaint's mouse gestures do")
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
                        && dockClick.contains("if DockExtrasSupport.wantsScrollEvents")
                        && dockClick.contains("if DockLock.shared.wantsPointerMoves")
                        && dockClick.contains("DockLock.shared.filter(event)"),
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

    private static func switcherSwipe(_ suite: TestSuite) {
        typealias Support = DockExtrasSupport
        func touches(_ x: CGFloat, _ count: Int = 3, y: CGFloat = 0.5) -> [Support.SwipeTouch] {
            (0..<count).map { Support.SwipeTouch(id: $0, position: CGPoint(x: x + CGFloat($0) * 0.1, y: y)) }
        }
        var detector = Support.SwitcherSwipeDetector()
        suite.expect(detector.handle(touches(0.2), fingers: 3, horizontal: true) == nil
                        && detector.handle(touches(0.25), fingers: 3, horizontal: true) == .open,
                     "three fingers moving sideways together open the switcher")
        suite.expect(detector.handle(touches(0.3), fingers: 3, horizontal: true) == nil
                        && detector.handle(touches(0.42), fingers: 3, horizontal: true) == .forward
                        && detector.handle(touches(0.37), fingers: 3, horizontal: true) == .backward,
                     "further travel steps the selection, either way")
        suite.expect(detector.handle(touches(0.37, 2), fingers: 3, horizontal: true) == .release,
                     "lifting a finger switches")
        var four = Support.SwitcherSwipeDetector()
        _ = four.handle(touches(0.2), fingers: 4, horizontal: true)
        suite.expect(four.handle(touches(0.3), fingers: 4, horizontal: true) == nil,
                     "three fingers do nothing when four are chosen")
        var diagonal = Support.SwitcherSwipeDetector()
        _ = diagonal.handle(touches(0.2), fingers: 3, horizontal: true)
        suite.expect(diagonal.handle(touches(0.25, y: 0.7), fingers: 3, horizontal: true) == nil
                        && diagonal.handle(touches(0.4, y: 0.7), fingers: 3, horizontal: true) == nil,
                     "a swipe that wanders off its axis is spent")
        suite.expect(Support.sanitizedSwipeFingers(4) == 4 && Support.sanitizedSwipeFingers(0) == 3
                        && Support.sanitizedSwipeFingers(7) == 3, "only three or four fingers")
        func side(_ dx: Double, natural: Bool = false, desktops: Bool = true) -> Support.TitleBarDecision {
            Support.titleBarDecision(deltaX: dx, deltaY: 0.2, natural: natural, isMomentum: false,
                                     sinceLastAction: 1, sidewaysSwitchesDesktop: desktops)
        }
        suite.expect(side(3) == .nextDesktop && side(-3) == .previousDesktop
                        && side(3, natural: true) == .previousDesktop && side(3, desktops: false) == .pass,
                     "sideways on a title bar switches desktop only when chosen (C8)")
    }

    private static func indicator(_ suite: TestSuite) {
        typealias Support = DockExtrasSupport
        let icon = CGRect(x: 100, y: 900, width: 60, height: 60)
        let line = Support.indicatorRect(icon: icon, dock: .bottom, style: .line)
        suite.expect(abs(line.midX - icon.midX) < 0.01 && line.minY == icon.maxY + 2 && line.height == 3
                        && line.width == 27,
                     "a bottom Dock's line sits centred 2 pt under the icon")
        let left = Support.indicatorRect(icon: icon, dock: .left, style: .dots)
        let right = Support.indicatorRect(icon: icon, dock: .right, style: .dots)
        suite.expect(left.maxX == icon.minX - 2 && right.minX == icon.maxX + 2
                        && abs(left.midY - icon.midY) < 0.01 && left.width == 5 && left.height == 5,
                     "side Docks get the mark beside the icon, on the screen's side")
        suite.expect(Support.indicatorStyle("dots") == .dots && Support.indicatorStyle("bogus") == .line
                        && Support.indicatorStyle(nil) == .line, "an unknown style reads as the line")
    }

    private static func dockLock(_ suite: TestSuite) {
        typealias Support = DockExtrasSupport
        let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let beside = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        let below = CGRect(x: 0, y: 982, width: 1920, height: 1080)
        suite.expect(Support.lockZones(screens: [laptop], locked: 0, dock: .bottom).isEmpty,
                     "one screen needs no lock")
        let zones = Support.lockZones(screens: [laptop, beside], locked: 0, dock: .bottom)
        suite.expect(zones == [Support.LockZone(rect: CGRect(x: 1512, y: 1433, width: 2560, height: 7),
                                                nudge: CGVector(dx: 0, dy: -7))],
                     "the other screen's bottom edge is guarded 7 pt deep")
        suite.expect(Support.heldPointer(CGPoint(x: 2000, y: 1438), zones: zones) == CGPoint(x: 2000, y: 1431)
                        && Support.heldPointer(CGPoint(x: 2000, y: 1400), zones: zones) == nil,
                     "a pointer pushing that edge is held back; elsewhere it is left alone")
        suite.expect(Support.lockZones(screens: [laptop, below], locked: 0, dock: .bottom).isEmpty,
                     "a screen whose Dock edge is fully covered cannot hold the Dock, so nothing is locked")
        let covered = Support.exposedEdge(of: CGRect(x: 0, y: 0, width: 2000, height: 1000), dock: .bottom,
                                          screens: [CGRect(x: 0, y: 0, width: 2000, height: 1000),
                                                    CGRect(x: 500, y: 1000, width: 1000, height: 800)])
        suite.expect(covered == [0...500, 1500...2000], "a screen below covers only its own stretch of the edge")
        suite.expect(Support.screenHoldingDock(CGRect(x: 2400, y: 1370, width: 600, height: 64),
                                               screens: [laptop, beside], orientation: .bottom) == 1
                        && Support.screenHoldingDock(CGRect(x: 400, y: 910, width: 600, height: 64),
                                                     screens: [laptop, beside], orientation: .bottom) == 0,
                     "the Dock's screen is read from where its icons are")
        let path = Support.callBackPath(locked: laptop, dock: .bottom, screens: [laptop, beside])
        suite.expect(path?.end == CGPoint(x: 60, y: 981) && path?.push == CGVector(dx: 0, dy: 8),
                     "the Dock is called back by pushing on the chosen screen's free edge")
    }

    private static func folders(_ suite: TestSuite) {
        let fileManager = FileManager.default
        let folder = fileManager.temporaryDirectory.appendingPathComponent("mantel-folder-pop-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: folder) }
        guard (try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else {
            suite.expect(false, "a scratch folder is available")
            return
        }
        for (index, name) in ["old.txt", "middle.txt", "new.txt", ".hidden"].enumerated() {
            let url = folder.appendingPathComponent(name)
            fileManager.createFile(atPath: url.path, contents: Data())
            try? fileManager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000 + Double(index) * 100)],
                                           ofItemAtPath: url.path)
        }
        let items = DockExtrasSupport.folderItems(in: folder, limit: 10)
        suite.expect(!items.contains { $0.url.lastPathComponent == ".hidden" } && items.count == 3,
                     "a Dock folder lists its visible files")
        suite.expect(DockExtrasSupport.folderItems(in: folder, limit: 2).count == 2
                        && DockExtrasSupport.folderItems(in: folder.appendingPathComponent("missing"), limit: 5).isEmpty,
                     "the list is capped, and a missing folder lists nothing")
    }
}
