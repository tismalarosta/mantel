// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// DockDoor/Utilities/DockLocker.swift.

import AppKit

/// C12: keeps the Dock on one screen. macOS moves the Dock to whichever
/// screen the pointer pushes against at its Dock edge; this holds the pointer
/// a few points short of that edge on every other screen (holding ⌥ lets it
/// through), and calls the Dock back when it is found elsewhere. A guest of
/// Vorssaint's Dock Click tap, which adds pointer moves to its mask only
/// while there are zones to guard (two screens or more).
final class DockLock {
    static let shared = DockLock()

    private var zones: [DockExtrasSupport.LockZone] = []
    private var screenObserver: NSObjectProtocol?
    private var callBack: DispatchWorkItem?
    private var callingBack = false

    private init() {}

    /// Whether the Dock tap should listen to pointer moves.
    var wantsPointerMoves: Bool { DockExtrasSupport.dockLockOn && !zones.isEmpty }

    func syncWithPreferences() {
        if DockExtrasSupport.dockLockOn {
            if screenObserver == nil {
                screenObserver = NotificationCenter.default.addObserver(
                    forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
                ) { [weak self] _ in
                    self?.refreshZones()
                    DockClickService.shared.syncWithPreferences()
                    self?.scheduleCallBack(after: 1.5)
                }
            }
            refreshZones()
            scheduleCallBack(after: 0.5)
        } else {
            if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
            screenObserver = nil
            zones = []
            callBack?.cancel()
        }
    }

    /// Runs inside the tap callback for every pointer move: a rectangle test,
    /// and the event's position moved in place when it is inside a zone.
    func filter(_ event: CGEvent) {
        guard !zones.isEmpty, !callingBack else { return }
        let flags = event.flags.union(CGEventSource.flagsState(.combinedSessionState))
        guard !flags.contains(.maskAlternate),
              let held = DockExtrasSupport.heldPointer(event.location, zones: zones) else { return }
        event.location = held
    }

    // MARK: - Screens

    private static var orientation: DockPreviewOrientation {
        DockPreviewOrientation.sanitized(UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation"))
    }

    private static func topLeftFrames() -> [CGRect] {
        guard let primary = NSScreen.screens.first?.frame.height else { return [] }
        return NSScreen.screens.map { DockExtrasSupport.topLeftRect(fromAppKit: $0.frame, primaryScreenHeight: primary) }
    }

    /// The chosen screen by its display UUID; the screen with the menu bar
    /// when none is chosen or the chosen one is not connected.
    static func lockedIndex() -> Int {
        let chosen = UserDefaults.standard.string(forKey: DefaultsKey.dockLockScreen) ?? ""
        return NSScreen.screens.firstIndex { uuid(of: $0) == chosen } ?? 0
    }

    static func uuid(of screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }

    func refreshZones() {
        zones = DockExtrasSupport.dockLockOn
            ? DockExtrasSupport.lockZones(screens: Self.topLeftFrames(), locked: Self.lockedIndex(),
                                          dock: Self.orientation)
            : []
    }

    // MARK: - Calling the Dock back

    func scheduleCallBack(after delay: TimeInterval) {
        callBack?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.callBackIfNeeded() }
        callBack = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// DockDoor's relocation: glide the pointer to the chosen screen's Dock
    /// edge and push, then put it back where it was. Skipped while ⌥ or the
    /// mouse button is held.
    private func callBackIfNeeded() {
        guard DockExtrasSupport.dockLockOn, !callingBack, NSScreen.screens.count > 1,
              let list = DockIcons.listFrame() else { return }
        let screens = Self.topLeftFrames()
        let locked = Self.lockedIndex()
        let orientation = Self.orientation
        guard let current = DockExtrasSupport.screenHoldingDock(list, screens: screens, orientation: orientation),
              current != locked,
              let path = DockExtrasSupport.callBackPath(locked: screens[locked], dock: orientation, screens: screens)
        else { return }
        guard !CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate) else { return }
        guard !CGEventSource.buttonState(.combinedSessionState, button: .left) else {
            return scheduleCallBack(after: 2)
        }
        let origin = CGEvent(source: nil)?.location
        callingBack = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let steps = 8
            for step in 0...steps {
                let t = CGFloat(step) / CGFloat(steps)
                Self.postMove(to: CGPoint(x: path.start.x + (path.end.x - path.start.x) * t,
                                          y: path.start.y + (path.end.y - path.start.y) * t),
                              delta: CGVector(dx: (path.end.x - path.start.x) / CGFloat(steps),
                                              dy: (path.end.y - path.start.y) / CGFloat(steps)))
                usleep(16_000)
            }
            for _ in 0..<6 {
                Self.postMove(to: path.end, delta: path.push)
                usleep(16_000)
            }
            usleep(150_000)
            if let origin { CGWarpMouseCursorPosition(origin) }
            DispatchQueue.main.async { self?.callingBack = false }
        }
    }

    private static func postMove(to point: CGPoint, delta: CGVector) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                  mouseCursorPosition: point, mouseButton: .left) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(delta.dx))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(delta.dy))
        event.post(tap: .cghidEventTap)
    }
}
