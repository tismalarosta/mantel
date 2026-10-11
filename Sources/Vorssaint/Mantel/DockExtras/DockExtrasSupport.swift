// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Behaviour follows DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// DockDoor/Utilities/DockObserver.swift (handleCmdRightClickQuit, handleDockScroll,
// handleTitleBarScroll), TrackpadGestureModifier.swift (preview swipes) and
// WindowPreviewHoverContainer.swift (checkForShakeGesture), TrackpadSwipeTrigger.swift
// (TrackpadSwipeDetector), DockLocker.swift (DockLockerGeometry) and
// ActiveAppIndicator/ActiveAppIndicatorPositioning.swift.

import CoreGraphics
import Foundation

/// The pure half of Mantel's DockDoor extras: which extras are on, and the
/// decisions their hooks make. Each extra is its own Features hub switch
/// (SPEC §3C) and changes nothing while it is off.
enum DockExtrasSupport {
    /// Spotify and Apple Music: scrolling on their icon can set the volume.
    static let mediaBundleIDs: Set<String> = ["com.spotify.client", "com.apple.Music"]
    /// Never quit from the Dock: Finder relaunches itself, and quitting
    /// Mantel from its own Dock tap would end the tap mid-event.
    static let protectedBundleIDs: Set<String> = ["com.apple.finder"]
    /// DockDoor's debounce between two scroll actions on an icon.
    static let scrollDebounce: TimeInterval = 0.3
    /// DockDoor ignores scroll deltas below this as noise.
    static let scrollNoise = 0.1
    /// DockDoor's volume sensitivity per scroll unit.
    static let volumeStep = 0.015

    static func isOn(_ feature: AppFeature, key: String, in defaults: UserDefaults = .standard) -> Bool {
        feature.isAvailable(in: defaults) && defaults.bool(forKey: key)
    }

    static var quitClickOn: Bool { isOn(.dockQuitClick, key: DefaultsKey.dockQuitClickEnabled) }
    static var scrollOn: Bool { isOn(.dockScroll, key: DefaultsKey.dockScrollEnabled) }
    static var massActionsOn: Bool { isOn(.dockPreviewMassActions, key: DefaultsKey.dockPreviewMassActionsEnabled) }
    static var windowButtonsOn: Bool {
        isOn(.dockPreviewWindowButtons, key: DefaultsKey.dockPreviewWindowButtonsEnabled)
    }

    static var swipeOn: Bool { isOn(.dockPreviewSwipe, key: DefaultsKey.dockPreviewSwipeEnabled) }
    static var shakeOn: Bool { isOn(.dockPreviewShake, key: DefaultsKey.dockPreviewShakeEnabled) }
    static var titleBarScrollOn: Bool { isOn(.titleBarScroll, key: DefaultsKey.titleBarScrollEnabled) }
    static var switcherSwipeOn: Bool { isOn(.trackpadSwitcherSwipe, key: DefaultsKey.trackpadSwitcherSwipeEnabled) }
    static var activeIndicatorOn: Bool { isOn(.dockActiveIndicator, key: DefaultsKey.dockActiveIndicatorEnabled) }
    static var dockLockOn: Bool { isOn(.dockLock, key: DefaultsKey.dockLockEnabled) }

    /// Whether the Dock tap should run for the extras alone.
    static var wantsDockTap: Bool { quitClickOn || scrollOn || titleBarScrollOn || dockLockOn }
    /// Whether the Dock tap should listen to scrolls: on Dock icons (C7) or
    /// on title bars (C8), both through the one tap.
    static var wantsScrollEvents: Bool { scrollOn || titleBarScrollOn }

    enum QuitIntent: Equatable { case none, quit, forceQuit }

    /// ⌘ right-click quits, ⌥⌘ right-click force-quits (DockDoor). Control
    /// or Shift keep the Dock's own menu, so nothing else is taken over.
    static func quitIntent(command: Bool, option: Bool, control: Bool, shift: Bool) -> QuitIntent {
        guard command, !control, !shift else { return .none }
        return option ? .forceQuit : .quit
    }

    static func canQuit(bundleID: String?, isOwnApp: Bool) -> Bool {
        guard !isOwnApp else { return false }
        return !(bundleID.map(protectedBundleIDs.contains) ?? false)
    }

    enum ScrollAction: Equatable { case none, show, hide, volume(Double) }

    /// One scroll on an icon. `deltaY` is the wheel's raw axis-1 delta and
    /// `naturalScrolling` the device's inversion, so "up" means the same
    /// gesture on every Mac (DockDoor normalizes the same way). Media apps
    /// turn the volume when `mediaVolume` is on; everything else shows (up)
    /// or hides (down), at most once per debounce.
    static func scrollAction(deltaY: Double, naturalScrolling: Bool, isMediaApp: Bool, mediaVolume: Bool,
                             sinceLastAction: TimeInterval) -> ScrollAction {
        guard deltaY.isFinite, abs(deltaY) > scrollNoise else { return .none }
        let normalized = naturalScrolling ? -deltaY : deltaY
        if isMediaApp, mediaVolume { return .volume(normalized * volumeStep) }
        guard sinceLastAction >= scrollDebounce else { return .none }
        return normalized > 0 ? .show : .hide
    }

    static func nextVolume(current: Double, change: Double) -> Double {
        min(1, max(0, current + change))
    }

    // MARK: - C3: swipe on a Dock preview

    enum SwipeDirection: Equatable { case up, down, left, right }
    enum SwipeAction: Equatable { case none, minimize, maximize }

    /// DockDoor's default swipe distance, in points of precise scrolling.
    static let swipeThreshold = 50.0

    /// One finished trackpad swipe, from its summed precise deltas. `natural`
    /// is the device's inversion, so the answer is where the fingers went on
    /// every Mac (DockDoor normalizes only the vertical axis; both are here,
    /// so a side Dock works with either scrolling direction).
    static func swipeDirection(totalX: Double, totalY: Double, natural: Bool,
                               threshold: Double = swipeThreshold) -> SwipeDirection? {
        guard totalX.isFinite, totalY.isFinite else { return nil }
        let up = natural ? -totalY : totalY
        let right = natural ? totalX : -totalX
        if abs(up) > abs(right), abs(up) > threshold { return up > 0 ? .up : .down }
        if abs(right) > abs(up), abs(right) > threshold { return right > 0 ? .right : .left }
        return nil
    }

    /// Toward the Dock minimizes, away from it maximizes (DockDoor's
    /// defaults); a sideways swipe along the Dock does nothing.
    static func swipeAction(_ direction: SwipeDirection?, dock: DockPreviewOrientation) -> SwipeAction {
        guard let direction else { return .none }
        let toward: SwipeDirection
        let away: SwipeDirection
        switch dock {
        case .bottom: (toward, away) = (.down, .up)
        case .left: (toward, away) = (.left, .right)
        case .right: (toward, away) = (.right, .left)
        }
        if direction == toward { return .minimize }
        if direction == away { return .maximize }
        return .none
    }

    // MARK: - C4: shake a dragged preview

    /// DockDoor's shake test, run on the last 20 pointer samples (one every
    /// 50 ms): at least 8 samples, 4 reversals of more than 5 pt each, and
    /// over 100 pt travelled.
    static let shakeSampleInterval: TimeInterval = 0.05
    static let shakeSampleLimit = 20

    static func isShake(_ points: [CGPoint]) -> Bool {
        guard points.count >= 8 else { return false }
        var steps: [CGVector] = []
        var distance: CGFloat = 0
        for i in 1 ..< points.count {
            let step = CGVector(dx: points[i].x - points[i - 1].x, dy: points[i].y - points[i - 1].y)
            steps.append(step)
            distance += hypot(step.dx, step.dy)
        }
        var reversals = 0
        for i in 1 ..< steps.count {
            let previous = steps[i - 1], current = steps[i]
            let flipsX = abs(previous.dx) > 5 && abs(current.dx) > 5 && (previous.dx > 0) != (current.dx > 0)
            let flipsY = abs(previous.dy) > 5 && abs(current.dy) > 5 && (previous.dy > 0) != (current.dy > 0)
            if flipsX || flipsY { reversals += 1 }
        }
        return reversals >= 4 && distance > 100
    }

    // MARK: - C8: scroll on a title bar

    enum TitleBarDecision: Equatable {
        /// Not a title bar scroll: the event goes on to the app.
        case pass
        /// Inside the debounce: kept from the app, nothing done.
        case swallow
        case maximize, centre
        /// Sideways, with "switch desktops" on: DockDoor's original C8.
        case previousDesktop, nextDesktop
    }

    /// DockDoor's debounce between two title bar actions and its noise floor.
    static let titleBarDebounce: TimeInterval = 0.35
    static let titleBarNoise = 0.15
    /// DockDoor's title bar height bounds, measured from the window's top
    /// to the close button, plus 12 pt.
    static let titleBarMinHeight: CGFloat = 48
    static let titleBarMaxHeight: CGFloat = 72

    /// One scroll over a title bar. Momentum (the glide after the fingers
    /// lift) never acts, and a sideways scroll goes on to the app: the
    /// desktop switching DockDoor did there was dropped (SPEC §3C, C8).
    static func titleBarDecision(deltaX: Double, deltaY: Double, natural: Bool, isMomentum: Bool,
                                 sinceLastAction: TimeInterval,
                                 sidewaysSwitchesDesktop: Bool = false) -> TitleBarDecision {
        guard deltaX.isFinite, deltaY.isFinite, !isMomentum,
              abs(deltaX) > titleBarNoise || abs(deltaY) > titleBarNoise else { return .pass }
        let sideways = abs(deltaX) > abs(deltaY)
        if sideways, !sidewaysSwitchesDesktop { return .pass }
        guard sinceLastAction >= titleBarDebounce else { return .swallow }
        if sideways {
            // DockDoor's normalization: the desktop on the side the fingers go toward.
            let right = natural ? -deltaX : deltaX
            return right > 0 ? .nextDesktop : .previousDesktop
        }
        let up = natural ? -deltaY : deltaY
        return up > 0 ? .maximize : .centre
    }

    /// The title bar band of a window, top-left screen coordinates (those
    /// of Accessibility and of CGEvent locations).
    static func titleBarRect(window: CGRect, closeButton: CGRect) -> CGRect {
        let inferred = closeButton.maxY - window.minY + 12
        let height = min(max(inferred, titleBarMinHeight), titleBarMaxHeight, window.height)
        return CGRect(x: window.minX, y: window.minY, width: window.width, height: height)
    }

    /// Whether a window already fills the screen's usable area, so a
    /// maximize would change nothing and leave nothing to restore.
    static func fills(_ frame: CGRect, visibleFrame: CGRect, tolerance: CGFloat = 8) -> Bool {
        abs(frame.minX - visibleFrame.minX) <= tolerance && abs(frame.minY - visibleFrame.minY) <= tolerance
            && abs(frame.width - visibleFrame.width) <= tolerance
            && abs(frame.height - visibleFrame.height) <= tolerance
    }

    /// An AppKit screen rect (bottom-left origin) in top-left coordinates.
    static func topLeftRect(fromAppKit rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    // MARK: - C9: trackpad swipe opens the switcher

    struct SwipeTouch: Equatable {
        let id: Int
        /// Normalized trackpad position, 0...1 on both axes.
        let position: CGPoint
    }

    enum SwitcherSwipeEvent: Equatable { case open, forward, backward, release }

    /// DockDoor's TrackpadSwipeDetector, as is: a swipe with exactly the
    /// chosen number of fingers, all moving the same way along the axis,
    /// opens the switcher; while it stays down, further travel steps the
    /// selection; lifting a finger releases (commits).
    struct SwitcherSwipeDetector {
        static let openDistance: CGFloat = 0.03
        static let firstStepDistance: CGFloat = 0.15
        static let stepDistance: CGFloat = 0.04
        static let maxOffAxisDistance: CGFloat = 0.1
        static let axisDominanceRatio: CGFloat = 1.5

        private var starts: [Int: CGPoint] = [:]
        private var isSpent = false
        private var hasStepped = false
        private(set) var isSwitching = false

        init() {}

        mutating func handle(_ touches: [SwipeTouch], fingers: Int, horizontal: Bool) -> SwitcherSwipeEvent? {
            if isSwitching {
                if touches.count < fingers {
                    isSwitching = false
                    isSpent = touches.count > 1
                    starts.removeAll()
                    return .release
                }
                guard let deltas = travel(touches) else { return nil }
                let along = deltas.map { horizontal ? $0.x : $0.y }.reduce(0, +) / CGFloat(deltas.count)
                guard abs(along) >= (hasStepped ? Self.stepDistance : Self.firstStepDistance) else { return nil }
                hasStepped = true
                rebase(touches)
                return along > 0 ? .forward : .backward
            }
            if touches.count <= 1 {
                isSpent = false
                starts.removeAll()
                return nil
            }
            if isSpent { return nil }
            if touches.count > fingers {
                isSpent = true
                return nil
            }
            guard touches.count == fingers else {
                starts.removeAll()
                return nil
            }
            guard let deltas = travel(touches) else { return nil }
            let along = deltas.map { horizontal ? $0.x : $0.y }
            let across = deltas.map { horizontal ? abs($0.y) : abs($0.x) }
            if across.contains(where: { $0 >= Self.maxOffAxisDistance }) {
                isSpent = true
                return nil
            }
            guard along.allSatisfy({ $0 >= Self.openDistance }) || along.allSatisfy({ $0 <= -Self.openDistance }),
                  zip(along.map(abs), across).allSatisfy({ $0 > $1 * Self.axisDominanceRatio })
            else { return nil }
            isSwitching = true
            hasStepped = false
            rebase(touches)
            return .open
        }

        private mutating func travel(_ touches: [SwipeTouch]) -> [CGPoint]? {
            let deltas = touches.compactMap { touch -> CGPoint? in
                guard let start = starts[touch.id] else { return nil }
                return CGPoint(x: touch.position.x - start.x, y: touch.position.y - start.y)
            }
            guard !deltas.isEmpty, deltas.count == touches.count else {
                rebase(touches)
                return nil
            }
            return deltas
        }

        private mutating func rebase(_ touches: [SwipeTouch]) {
            starts = Dictionary(touches.map { ($0.id, $0.position) }, uniquingKeysWith: { first, _ in first })
        }
    }

    static func sanitizedSwipeFingers(_ raw: Int) -> Int { raw == 4 ? 4 : 3 }

    // MARK: - C11: active app indicator under Dock icons

    enum IndicatorStyle: String, CaseIterable { case line, dots }

    static func indicatorStyle(_ raw: String?) -> IndicatorStyle { IndicatorStyle(rawValue: raw ?? "") ?? .line }

    /// Where the mark for one Dock icon goes, in top-left coordinates: a
    /// line or dot centred under the icon (bottom Dock) or beside it (side
    /// Docks), 2 pt from its edge, as DockDoor places its bar.
    static func indicatorRect(icon: CGRect, dock: DockPreviewOrientation, style: IndicatorStyle) -> CGRect {
        let thickness: CGFloat = style == .line ? 3 : 5
        let length: CGFloat = style == .line ? max(8, (dock == .bottom ? icon.width : icon.height) * 0.45) : 5
        switch dock {
        case .bottom:
            return CGRect(x: icon.midX - length / 2, y: icon.maxY + 2, width: length, height: thickness)
        case .left:
            return CGRect(x: icon.minX - 2 - thickness, y: icon.midY - length / 2, width: thickness, height: length)
        case .right:
            return CGRect(x: icon.maxX + 2, y: icon.midY - length / 2, width: thickness, height: length)
        }
    }

    // MARK: - C12: keep the Dock on one screen

    struct LockZone: Equatable {
        let rect: CGRect
        let nudge: CGVector
    }

    /// DockDoor's trigger depth: the strip along a screen's Dock edge where
    /// pushing the pointer would call the Dock over.
    static let lockZoneDepth: CGFloat = 7

    /// The stretches of a screen's Dock edge that touch no other screen
    /// (only there can the pointer push against it), top-left coordinates.
    static func exposedEdge(of frame: CGRect, dock: DockPreviewOrientation,
                            screens: [CGRect]) -> [ClosedRange<CGFloat>] {
        let edge: CGFloat
        var free: [ClosedRange<CGFloat>]
        switch dock {
        case .bottom: (edge, free) = (frame.maxY, [frame.minX...frame.maxX])
        case .left: (edge, free) = (frame.minX, [frame.minY...frame.maxY])
        case .right: (edge, free) = (frame.maxX, [frame.minY...frame.maxY])
        }
        for other in screens where other != frame {
            let touches: Bool
            let span: ClosedRange<CGFloat>
            switch dock {
            case .bottom: (touches, span) = (abs(other.minY - edge) <= 2, other.minX...other.maxX)
            case .left: (touches, span) = (abs(other.maxX - edge) <= 2, other.minY...other.maxY)
            case .right: (touches, span) = (abs(other.minX - edge) <= 2, other.minY...other.maxY)
            }
            guard touches else { continue }
            free = free.flatMap { piece -> [ClosedRange<CGFloat>] in
                var pieces: [ClosedRange<CGFloat>] = []
                if span.lowerBound - piece.lowerBound > 0.5 {
                    pieces.append(piece.lowerBound...min(piece.upperBound, span.lowerBound))
                }
                if piece.upperBound - span.upperBound > 0.5 {
                    pieces.append(max(piece.lowerBound, span.upperBound)...piece.upperBound)
                }
                return span.upperBound <= piece.lowerBound || span.lowerBound >= piece.upperBound ? [piece] : pieces
            }
        }
        return free.filter { $0.upperBound - $0.lowerBound > 0.5 }
    }

    /// The strips on every other screen where the pointer is held back by a
    /// few points, so the Dock never follows it there. None with one screen,
    /// or when the chosen screen's own Dock edge is fully covered (macOS
    /// could not put the Dock there, DockDoor's guard).
    static func lockZones(screens: [CGRect], locked: Int, dock: DockPreviewOrientation) -> [LockZone] {
        guard screens.count > 1, screens.indices.contains(locked),
              !exposedEdge(of: screens[locked], dock: dock, screens: screens).isEmpty else { return [] }
        let depth = lockZoneDepth
        var zones: [LockZone] = []
        for (index, frame) in screens.enumerated() where index != locked {
            for span in exposedEdge(of: frame, dock: dock, screens: screens) {
                let length = span.upperBound - span.lowerBound
                switch dock {
                case .bottom:
                    zones.append(LockZone(rect: CGRect(x: span.lowerBound, y: frame.maxY - depth, width: length, height: depth),
                                          nudge: CGVector(dx: 0, dy: -depth)))
                case .left:
                    zones.append(LockZone(rect: CGRect(x: frame.minX, y: span.lowerBound, width: depth, height: length),
                                          nudge: CGVector(dx: depth, dy: 0)))
                case .right:
                    zones.append(LockZone(rect: CGRect(x: frame.maxX - depth, y: span.lowerBound, width: depth, height: length),
                                          nudge: CGVector(dx: -depth, dy: 0)))
                }
            }
        }
        return zones
    }

    /// Where a pointer inside a lock zone is held instead; nil leaves it be.
    static func heldPointer(_ point: CGPoint, zones: [LockZone]) -> CGPoint? {
        guard let zone = zones.first(where: { $0.rect.contains(point) }) else { return nil }
        return CGPoint(x: point.x + zone.nudge.dx, y: point.y + zone.nudge.dy)
    }

    /// The pointer path that calls the Dock back onto the chosen screen:
    /// macOS only moves it when the pointer pushes on a free stretch of that
    /// screen's Dock edge (DockDoor's relocation).
    static func callBackPath(locked: CGRect, dock: DockPreviewOrientation,
                             screens: [CGRect]) -> (start: CGPoint, end: CGPoint, push: CGVector)? {
        guard let span = exposedEdge(of: locked, dock: dock, screens: screens)
            .max(by: { ($0.upperBound - $0.lowerBound) < ($1.upperBound - $1.lowerBound) }) else { return nil }
        let along = span.lowerBound + min(60, (span.upperBound - span.lowerBound) / 2)
        switch dock {
        case .bottom:
            return (CGPoint(x: along, y: locked.maxY - 80), CGPoint(x: along, y: locked.maxY - 1), CGVector(dx: 0, dy: 8))
        case .left:
            return (CGPoint(x: locked.minX + 80, y: along), CGPoint(x: locked.minX, y: along), CGVector(dx: -8, dy: 0))
        case .right:
            return (CGPoint(x: locked.maxX - 80, y: along), CGPoint(x: locked.maxX - 1, y: along), CGVector(dx: 8, dy: 0))
        }
    }

    /// Which screen holds the Dock, from the Dock list's frame: the screen
    /// spanning its middle along the long axis, nearest on the short one.
    static func screenHoldingDock(_ dock: CGRect, screens: [CGRect], orientation: DockPreviewOrientation) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (index, frame) in screens.enumerated() {
            let distance: CGFloat
            switch orientation {
            case .bottom:
                guard dock.midX >= frame.minX, dock.midX <= frame.maxX else { continue }
                distance = min(abs(frame.maxY - dock.minY), abs(frame.maxY - dock.maxY))
            case .left:
                guard dock.midY >= frame.minY, dock.midY <= frame.maxY else { continue }
                distance = min(abs(frame.minX - dock.maxX), abs(frame.minX - dock.minX))
            case .right:
                guard dock.midY >= frame.minY, dock.midY <= frame.maxY else { continue }
                distance = min(abs(frame.maxX - dock.minX), abs(frame.maxX - dock.maxX))
            }
            if best == nil || distance < best!.distance { best = (index, distance) }
        }
        return best?.index
    }
}
