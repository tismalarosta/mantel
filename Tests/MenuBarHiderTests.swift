// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// The menu bar hider's pure rules (Ice's mechanics), its registration and
/// the source contracts that keep it to Ice's macOS 26 safe parts.
enum MenuBarHiderTests {
    static func run(_ suite: TestSuite) {
        mainIcon(suite)
        lengths(suite)
        triggers(suite)
        geometry(suite)
        registration(suite)
        sourceContracts(suite)
    }

    private static func mainIcon(_ suite: TestSuite) {
        typealias Support = MenuBarHiderSupport
        func action(_ active: Bool, right: Bool = false, option: Bool = false, control: Bool = false,
                    always: Bool = true) -> MenuBarMainIconAction {
            Support.mainIconAction(hiderActive: active, rightClick: right, option: option, control: control,
                                   alwaysHiddenEnabled: always)
        }
        suite.expect(action(false) == .vorssaintDefault && action(false, right: true) == .vorssaintDefault,
                     "with the hider off, Vorssaint's icon clicks exactly as before")
        suite.expect(action(true) == .toggleHidden, "a click on the icon shows and hides the hidden icons")
        suite.expect(action(true, right: true) == .openPanel, "right-click opens the Vorssaint panel (SPEC §2)")
        suite.expect(action(true, control: true) == .openMenu && action(true, right: true, control: true) == .openMenu,
                     "Control-click reaches Vorssaint's menu")
        suite.expect(action(true, option: true) == .toggleAlwaysHidden,
                     "Option-click reaches the always-hidden section")
        suite.expect(action(true, option: true, always: false) == .toggleHidden,
                     "without an always-hidden section, Option-click is a plain click")
    }

    private static func lengths(_ suite: TestSuite) {
        typealias Support = MenuBarHiderSupport
        let hidden = Support.dividerLengths(hiddenShown: false, alwaysHiddenShown: false)
        suite.expect(hidden.hidden == 10_000 && hidden.alwaysHidden == 10_000,
                     "hidden sections stretch their divider to Ice's 10,000 pt")
        let shown = Support.dividerLengths(hiddenShown: true, alwaysHiddenShown: false)
        suite.expect(shown.hidden == nil && shown.alwaysHidden == 10_000,
                     "showing the hidden icons keeps the always-hidden ones away")
        let all = Support.dividerLengths(hiddenShown: true, alwaysHiddenShown: true)
        suite.expect(all.hidden == nil && all.alwaysHidden == nil, "showing both returns both dividers to size")
        suite.expect(Support.dividerLengths(hiddenShown: false, alwaysHiddenShown: true).alwaysHidden == 10_000,
                     "the always-hidden section never shows while the hidden one is hidden")
    }

    private static func triggers(_ suite: TestSuite) {
        typealias Support = MenuBarHiderSupport
        suite.expect(Support.scrollIntent(deltaX: 0, deltaY: 12) == true
                        && Support.scrollIntent(deltaX: -12, deltaY: 0) == false
                        && Support.scrollIntent(deltaX: 3, deltaY: 4) == nil,
                     "scrolling past an average of ±5 shows or hides, smaller moves do nothing")
        suite.expect(Support.sanitizedHoverDelay(-1) == 0 && Support.sanitizedHoverDelay(3) == 1
                        && Support.sanitizedHoverDelay(0.26) == 0.3 && Support.sanitizedHoverDelay(.nan) == 0.2,
                     "the hover delay stays between 0 and 1 s in tenths, Ice's default 0.2 s")
        suite.expect(Support.sanitizedRehideInterval(1) == 5 && Support.sanitizedRehideInterval(500) == 120
                        && Support.sanitizedRehideInterval(15.4) == 15,
                     "the rehide delay stays between 5 and 120 s, Ice's default 15 s")
        suite.expect(MenuBarRehideStrategy.allCases.map(\.rawValue) == ["smart", "timed", "focusedApp"]
                        && MenuBarRehideStrategy.sanitized("bogus") == .smart,
                     "the three rehide strategies keep stable ids and fall back to smart")
    }

    private static func geometry(_ suite: TestSuite) {
        typealias Support = MenuBarHiderSupport
        suite.expect(Support.seedPosition(mainPosition: 300, alwaysHidden: false) == 301
                        && Support.seedPosition(mainPosition: 300, alwaysHidden: true) == 302,
                     "new dividers start just left of Vorssaint's icon")
        suite.expect(Support.seedPosition(mainPosition: nil, alwaysHidden: false) == 1
                        && Support.seedPosition(mainPosition: -3, alwaysHidden: true) == 2,
                     "with no saved icon position, the dividers take Ice's own seeds")

        suite.expect(Support.position(leftOf: 1200, screenMaxX: 1512) == 313
                        && Support.position(leftOf: 1600, screenMaxX: 1512) == 1,
                     "a divider is placed one point left of the icon it guards, measured from the right edge")
        let icon = CGRect(x: 1200, y: 945, width: 30, height: 37)
        suite.expect(Support.isMisplaced(divider: CGRect(x: 1240, y: 945, width: 14, height: 37), rightNeighbour: icon)
                        && Support.isMisplaced(divider: CGRect(x: -8500, y: 945, width: 10_000, height: 37),
                                               rightNeighbour: icon),
                     "a divider right of Vorssaint's icon, shown or stretched, is caught (Matisse, 2026-10-11)")
        suite.expect(!Support.isMisplaced(divider: CGRect(x: 1186, y: 945, width: 14, height: 37), rightNeighbour: icon)
                        && !Support.isMisplaced(divider: CGRect(x: -8800, y: 945, width: 10_000, height: 37),
                                                rightNeighbour: icon),
                     "a divider left of the icon stays where it is")
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let bar = CGRect(x: 0, y: 945, width: 1512, height: 38)
        let notch = Support.notchRect(screenFrame: screen,
                                      auxiliaryLeft: CGRect(x: 0, y: 945, width: 660, height: 37),
                                      auxiliaryRight: CGRect(x: 852, y: 945, width: 660, height: 37),
                                      menuBarHeight: 37)
        suite.expect(notch == CGRect(x: 660, y: 945, width: 192, height: 37),
                     "the notch is the gap between the two top areas")
        suite.expect(Support.notchRect(screenFrame: screen, auxiliaryLeft: nil, auxiliaryRight: nil,
                                       menuBarHeight: 24) == nil,
                     "a display without a notch has none")
        let appMenu = CGRect(x: 0, y: 945, width: 400, height: 37)
        let items = [CGRect(x: 1300, y: 945, width: 30, height: 37)]
        func empty(_ x: CGFloat, _ y: CGFloat = 960) -> Bool {
            Support.isEmptyMenuBarSpace(CGPoint(x: x, y: y), menuBar: bar, appMenu: appMenu,
                                        statusItems: items, notch: notch)
        }
        suite.expect(empty(500) && empty(1000), "the bar between the app menus and the icons is empty space")
        suite.expect(!empty(200), "the app's own menus are not empty space")
        suite.expect(!empty(700), "the notch is never empty menu bar space (SPEC)")
        suite.expect(!empty(1310), "a status item is not empty space")
        suite.expect(!empty(500, 500), "below the menu bar is not menu bar")
    }

    private static func registration(_ suite: TestSuite) {
        let feature = AppFeature.menuBarHider
        suite.expect(!feature.installedByDefault && feature.group == .tools
                        && feature.permissions == [.accessibility]
                        && feature.enabledKeys == [DefaultsKey.menuBarHiderEnabled]
                        && feature.energyProfile == .mouse,
                     "the hider is an opt-in Tools feature using Accessibility and mouse monitors")
        let hidden = GlobalShortcutRole.menuBarHiderToggleHidden
        let always = GlobalShortcutRole.menuBarHiderToggleAlwaysHidden
        suite.expect(hidden.defaultShortcut.keyCode == Int64(kVK_ANSI_I)
                        && always.defaultShortcut.keyCode == Int64(kVK_ANSI_O)
                        && hidden.defaultShortcut.modifiers == [.control, .option, .command]
                        && always.defaultShortcut.modifiers == [.control, .option, .command],
                     "the hider shortcuts default to ⌃⌥⌘I and ⌃⌥⌘O")
        suite.expect(hidden.requiredEnableKeys.contains(DefaultsKey.menuBarHiderShortcutsEnabled)
                        && always.requiredEnableKeys.contains(DefaultsKey.menuBarHiderAlwaysHiddenEnabled)
                        && hidden.feature == .menuBarHider && always.feature == .menuBarHider,
                     "the shortcuts only register behind their own switch, like Ice's unset hotkeys")
        let defaults = Defaults.registeredDefaults
        suite.expect(defaults[DefaultsKey.menuBarHiderShortcutsEnabled] as? Bool == false
                        && defaults[DefaultsKey.menuBarHiderShowOnClick] as? Bool == true
                        && defaults[DefaultsKey.menuBarHiderShowOnHover] as? Bool == false
                        && defaults[DefaultsKey.menuBarHiderShowOnScroll] as? Bool == true
                        && defaults[DefaultsKey.menuBarHiderAutoRehide] as? Bool == true
                        && defaults[DefaultsKey.menuBarHiderRehideStrategy] as? String == "smart"
                        && defaults[DefaultsKey.menuBarHiderAlwaysHiddenEnabled] as? Bool == false,
                     "defaults match Ice's: click and scroll on, hover off, smart rehide, no always-hidden")
        for language in AppLanguage.allCases {
            let text = FeatureStrings.menuBarHider(language)
            suite.expect(!text.title.isEmpty && text.hoverDelayFormat.contains("%@")
                            && text.rehideIntervalFormat.contains("%d")
                            && MenuBarRehideStrategy.allCases.allSatisfy { !text.label(for: $0).isEmpty },
                         "the menu bar hider has complete strings in \(language.rawValue)")
        }
    }

    private static func sourceContracts(_ suite: TestSuite) {
        let service = (try? String(contentsOfFile: "Sources/Vorssaint/Mantel/MenuBarHider/MenuBarHiderService.swift",
                                   encoding: .utf8)) ?? ""
        suite.expect(!service.isEmpty, "the menu bar hider source is readable")
        suite.expect(!service.contains("constraintsAffectingLayout") && !service.contains("@_silgen_name")
                        && !service.contains("CGWindowListCreateImage"),
                     "phase 1 avoids Ice's fragile parts: no layout-constraint hack, private calls or window images")
        suite.expect(!service.contains("RegisterEventHotKey") && service.contains("QuickToolHotkey(id: 2603)"),
                     "the hider's shortcuts go through QuickToolHotkey")
        suite.expect(service.contains("defaults.set(saved, forKey: key)"),
                     "removing a divider keeps its saved position (Ice's note)")
        let controller = (try? String(contentsOfFile: "Sources/Vorssaint/App/StatusItemController.swift",
                                      encoding: .utf8)) ?? ""
        suite.expect(controller.contains("MenuBarHiderService.shared.mainIconAction(for: NSApp.currentEvent)")
                        && !controller.contains("NSStatusBar.system.statusItem(withLength: MenuBarHider"),
                     "Vorssaint's own icon is the hider's control: one hook, no second app icon")
    }
}
