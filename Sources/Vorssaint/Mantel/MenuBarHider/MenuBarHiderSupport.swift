// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Hiding mechanics and defaults follow Ice by Jordan Baird (github.com/jordanbaird/Ice, GPL-3.0),
// MenuBar/ControlItem/ControlItem.swift, Events/EventManager.swift, Utilities/RehideStrategy.swift.

import CoreGraphics
import Foundation

/// When shown icons hide again on their own. Stored by raw value; cases can
/// be added but never renamed (Ice's `RehideStrategy`, same three choices).
enum MenuBarRehideStrategy: String, CaseIterable {
    /// A click in an ordinary app window, or a Space change.
    case smart
    /// A fixed time after the pointer leaves the menu bar.
    case timed
    /// The frontmost app changes while the pointer is outside the menu bar.
    case focusedApp

    static let fallback: MenuBarRehideStrategy = .smart

    static func sanitized(_ raw: String?) -> MenuBarRehideStrategy {
        raw.flatMap(MenuBarRehideStrategy.init(rawValue:)) ?? fallback
    }
}

/// What a click on Vorssaint's own icon does while the hider owns it.
enum MenuBarMainIconAction: Equatable {
    /// The hider is off: Vorssaint's usual left and right click.
    case vorssaintDefault
    case toggleHidden
    case toggleAlwaysHidden
    case openPanel
    case openMenu
}

/// The pure half of the menu bar hider: lengths, triggers, positions.
enum MenuBarHiderSupport {
    /// Ice's expanded length: wide enough to push every item to its left
    /// past the screen edge on any display.
    static let expandedLength: CGFloat = 10_000

    /// macOS 27 rebuilt the menu bar (MenuBarAgent) and drops any item wider
    /// than half the display, so the expanded divider hides nothing there.
    /// shortcut: off on macOS 27+, port Ice's concealment (jordanbaird/Ice PR #995) once it ships.
    static func isSupported(majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> Bool {
        majorVersion < 27
    }
    /// The divider autosave names. Stable: macOS keys the saved position on them.
    static let hiddenDividerName = "MantelHiddenDivider"
    static let alwaysHiddenDividerName = "MantelAlwaysHiddenDivider"

    static let hoverDelayRange = 0.0...1.0
    static let defaultHoverDelay = 0.2
    static let rehideIntervalRange = 5.0...120.0
    static let defaultRehideInterval = 15.0
    /// Ice shows on an average scroll delta above 5 and hides below −5.
    static let scrollThreshold = 5.0
    /// Ice waits this long after a click outside before deciding to rehide.
    static let smartRehideDelay: TimeInterval = 0.25

    static func sanitizedHoverDelay(_ value: Double) -> Double {
        guard value.isFinite else { return defaultHoverDelay }
        return (min(max(value, hoverDelayRange.lowerBound), hoverDelayRange.upperBound) * 10).rounded() / 10
    }

    static func sanitizedRehideInterval(_ value: Double) -> Double {
        guard value.isFinite else { return defaultRehideInterval }
        return min(max(value, rehideIntervalRange.lowerBound), rehideIntervalRange.upperBound).rounded()
    }

    /// The main icon while the hider is on (SPEC §2): click shows and hides,
    /// ⌥-click reaches the always-hidden section, right-click opens the
    /// Vorssaint panel and ⌃-click its menu.
    static func mainIconAction(hiderActive: Bool, rightClick: Bool, option: Bool, control: Bool,
                               alwaysHiddenEnabled: Bool) -> MenuBarMainIconAction {
        guard hiderActive else { return .vorssaintDefault }
        if control { return .openMenu }
        if rightClick { return .openPanel }
        if option, alwaysHiddenEnabled { return .toggleAlwaysHidden }
        return .toggleHidden
    }

    /// The length each divider should have. The always-hidden section can
    /// only show when the hidden one does (Ice keeps them nested).
    static func dividerLengths(hiddenShown: Bool, alwaysHiddenShown: Bool)
        -> (hidden: CGFloat?, alwaysHidden: CGFloat?) {
        // nil = natural (variable) length.
        let hidden: CGFloat? = hiddenShown ? nil : expandedLength
        let alwaysHidden: CGFloat? = hiddenShown && alwaysHiddenShown ? nil : expandedLength
        return (hidden, alwaysHidden)
    }

    /// Ice's scroll rule: the mean of both axes, past ±5.
    static func scrollIntent(deltaX: Double, deltaY: Double) -> Bool? {
        let average = (deltaX + deltaY) / 2
        if average > scrollThreshold { return true }
        if average < -scrollThreshold { return false }
        return nil
    }

    /// Where a new divider starts: just left of Vorssaint's icon. macOS
    /// measures a saved position from the right edge, so a larger number
    /// sits further left. With nothing saved for the icon, the dividers take
    /// Ice's own seeds.
    static func seedPosition(mainPosition: Double?, alwaysHidden: Bool) -> Double {
        let step = alwaysHidden ? 2.0 : 1.0
        guard let mainPosition, mainPosition.isFinite, mainPosition >= 0 else { return step }
        return mainPosition + step
    }

    /// A saved position that puts an item just left of one whose left edge
    /// is at `itemMinX`. macOS keeps the spot as the distance from the
    /// screen's right edge, so one more point lands immediately to its left.
    static func position(leftOf itemMinX: CGFloat, screenMaxX: CGFloat) -> Double {
        Double(max(0, screenMaxX - itemMinX)) + 1
    }

    /// A divider must sit left of the item it guards. Measured on its right
    /// edge, which is the only edge on screen while it is stretched.
    static func isMisplaced(divider: CGRect, rightNeighbour: CGRect) -> Bool {
        divider.maxX > rightNeighbour.minX + 2
    }

    /// The notch between the two auxiliary top areas, in the screen's own
    /// coordinates; nil on a display without one.
    static func notchRect(screenFrame: CGRect, auxiliaryLeft: CGRect?, auxiliaryRight: CGRect?,
                          menuBarHeight: CGFloat) -> CGRect? {
        guard let left = auxiliaryLeft, let right = auxiliaryRight, right.minX > left.maxX else { return nil }
        return CGRect(x: left.maxX, y: screenFrame.maxY - menuBarHeight,
                      width: right.minX - left.maxX, height: menuBarHeight)
    }

    /// Whether a point is empty menu bar: inside the bar, and not over the
    /// app's menus, any status item, or the notch (SPEC: never treat the
    /// notch as empty space). All rects share one coordinate space.
    static func isEmptyMenuBarSpace(_ point: CGPoint, menuBar: CGRect, appMenu: CGRect?,
                                    statusItems: [CGRect], notch: CGRect?) -> Bool {
        guard menuBar.contains(point) else { return false }
        if let appMenu, point.x <= appMenu.maxX { return false }
        if let notch, notch.contains(point) { return false }
        return !statusItems.contains { $0.insetBy(dx: -1, dy: -1).contains(point) }
    }
}
