// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// DockDoor/Utilities/DockObserver.swift (handleCmdRightClickQuit, handleDockScroll).

import AppKit

/// C6 (⌘ right-click quits) and C7 (scroll on an icon) as a guest of
/// Vorssaint's Dock Click tap: one Dock tap, one Dock hit test (SPEC rule 4).
/// `DockClickService` forwards right clicks and scrolls here and swallows
/// the event when this returns true.
final class DockExtrasTap {
    static let shared = DockExtrasTap()

    /// A consumed ⌘ right-click must take its mouse-up along, or the Dock
    /// would open its menu on the release.
    private var swallowNextRightUp = false
    private var lastScrollAction: CFAbsoluteTime = 0
    /// One Dock hit test per short scroll burst instead of one per event.
    private var scrollTarget: (app: NSRunningApplication, point: CGPoint, at: CFAbsoluteTime)?

    private init() {}

    /// Runs on the main run loop, inside the tap callback, so it stays short.
    func handle(type: CGEventType, event: CGEvent,
                insideDock: (CGPoint) -> Bool,
                applicationAt: (CGPoint) -> NSRunningApplication?) -> Bool {
        switch type {
        case .rightMouseDown: return handleRightDown(event, insideDock: insideDock, applicationAt: applicationAt)
        case .rightMouseUp:
            guard swallowNextRightUp else { return false }
            swallowNextRightUp = false
            return true
        case .scrollWheel: return handleScroll(event, insideDock: insideDock, applicationAt: applicationAt)
        default: return false
        }
    }

    private func handleRightDown(_ event: CGEvent, insideDock: (CGPoint) -> Bool,
                                 applicationAt: (CGPoint) -> NSRunningApplication?) -> Bool {
        swallowNextRightUp = false
        guard DockExtrasSupport.quitClickOn else { return false }
        let flags = event.flags
        let intent = DockExtrasSupport.quitIntent(command: flags.contains(.maskCommand),
                                                  option: flags.contains(.maskAlternate),
                                                  control: flags.contains(.maskControl),
                                                  shift: flags.contains(.maskShift))
        guard intent != .none else { return false }
        let point = event.location
        guard insideDock(point), let app = applicationAt(point),
              DockExtrasSupport.canQuit(bundleID: app.bundleIdentifier,
                                        isOwnApp: app.processIdentifier == ProcessInfo.processInfo.processIdentifier)
        else { return false }
        swallowNextRightUp = true
        DispatchQueue.main.async {
            if intent == .forceQuit { app.forceTerminate() } else { app.terminate() }
        }
        return true
    }

    private func handleScroll(_ event: CGEvent, insideDock: (CGPoint) -> Bool,
                              applicationAt: (CGPoint) -> NSRunningApplication?) -> Bool {
        guard DockExtrasSupport.scrollOn else { return false }
        let point = event.location
        guard insideDock(point) else { return false }
        let now = CFAbsoluteTimeGetCurrent()
        let app: NSRunningApplication
        if let cached = scrollTarget, now - cached.at < 0.25,
           hypot(cached.point.x - point.x, cached.point.y - point.y) < 6, !cached.app.isTerminated {
            app = cached.app
        } else if let found = applicationAt(point) {
            app = found
            scrollTarget = (found, point, now)
        } else {
            scrollTarget = nil
            return false
        }
        let natural = NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice ?? false
        let action = DockExtrasSupport.scrollAction(
            deltaY: event.getDoubleValueField(.scrollWheelEventDeltaAxis1),
            naturalScrolling: natural,
            isMediaApp: app.bundleIdentifier.map(DockExtrasSupport.mediaBundleIDs.contains) ?? false,
            mediaVolume: UserDefaults.standard.bool(forKey: DefaultsKey.dockScrollMediaVolume),
            sinceLastAction: now - lastScrollAction)
        switch action {
        case .none:
            break
        case .show:
            lastScrollAction = now
            DispatchQueue.main.async {
                if app.isHidden { app.unhide() }
                app.activate()
            }
        case .hide:
            lastScrollAction = now
            DispatchQueue.main.async { app.hide() }
        case .volume(let change):
            // Vorssaint's mixer owns the system volume (SPEC rule 4).
            DispatchQueue.main.async {
                guard let current = AppVolumeMixer.systemOutputVolume() else { return }
                AppVolumeMixer.setSystemOutputVolume(DockExtrasSupport.nextVolume(current: current, change: change))
            }
        }
        // Over an app icon the scroll is ours, debounce included (DockDoor):
        // the Dock does nothing with it anyway.
        return true
    }
}
