// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// DockDoor/Utilities/TrackpadSwipeTrigger.swift.

import AppKit
import Carbon.HIToolbox

/// C9: a three- or four-finger swipe opens Vorssaint's switcher, further
/// travel steps through it, lifting the fingers switches. The switcher is
/// driven the way the keyboard drives it (its shortcut, then the arrow
/// keys, then the modifier's release), so it needs no hook of its own.
///
/// Reading touches takes a listen-only tap on gesture events: it can only
/// watch, never block, and runs only while this extra is installed and
/// Vorssaint's switcher is too. Vorssaint has no gesture stream to share
/// (middle click reads the touch device itself, for its own taps).
final class TrackpadSwitcherSwipe {
    static let shared = TrackpadSwitcherSwipe()

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var detector = DockExtrasSupport.SwitcherSwipeDetector()
    /// The switcher's modifiers while a swipe holds it open, nil otherwise.
    private var heldFlags: CGEventFlags?
    /// A swipe whose fingers' release never arrives still lets go.
    private var releaseGuard: DispatchWorkItem?

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in self?.syncWithPreferences() }
    }

    private var wanted: Bool {
        DockExtrasSupport.switcherSwipeOn && AppFeature.switcher.isAvailable
    }

    func syncWithPreferences() {
        if SessionActivitySupport.tapShouldRun(featureWanted: wanted,
                                               accessibilityGranted: AXIsProcessTrusted(),
                                               sessionIsActive: SessionActivity.shared.isActive) {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard tap == nil else { return }
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: NSEvent.EventTypeMask.gesture.rawValue,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let swipe = Unmanaged<TrackpadSwitcherSwipe>.fromOpaque(userInfo).takeUnretainedValue()
                swipe.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stop() {
        letGo()
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        detector = DockExtrasSupport.SwitcherSwipeDetector()
    }

    /// On the main run loop, inside the tap callback.
    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type.rawValue == NSEvent.EventType.gesture.rawValue,
              let nsEvent = NSEvent(cgEvent: event) else { return }
        let touches = nsEvent.allTouches().filter { $0.type == .indirect }
        guard !touches.isEmpty else { return }
        let down = touches.filter { NSTouch.Phase.touching.contains($0.phase) && !$0.isResting }
        let swipeTouches = down.count > 1
            ? down.map { DockExtrasSupport.SwipeTouch(id: $0.identity.hash, position: $0.normalizedPosition) }
            : []
        let defaults = UserDefaults.standard
        let fingers = DockExtrasSupport.sanitizedSwipeFingers(defaults.integer(forKey: DefaultsKey.trackpadSwitcherSwipeFingers))
        let horizontal = defaults.string(forKey: DefaultsKey.trackpadSwitcherSwipeDirection) != "vertical"
        guard let swipe = detector.handle(swipeTouches, fingers: fingers, horizontal: horizontal) else { return }
        DispatchQueue.main.async { [weak self] in self?.perform(swipe) }
    }

    private func perform(_ swipe: DockExtrasSupport.SwitcherSwipeEvent) {
        switch swipe {
        case .open:
            guard wanted, heldFlags == nil else { return }
            let shortcut = GlobalShortcut.saved(for: DefaultsKey.switcherShortcut, fallback: .switcherDefault)
            let flags = shortcut.modifiers.cgFlags
            heldFlags = flags
            press(CGKeyCode(shortcut.keyCode), flags: flags)
            armReleaseGuard()
        case .forward, .backward:
            guard let flags = heldFlags else { return }
            press(CGKeyCode(swipe == .forward ? kVK_RightArrow : kVK_LeftArrow), flags: flags)
            armReleaseGuard()
        case .release:
            letGo()
        }
    }

    /// Lifting the fingers is the modifier's release: the switcher commits.
    private func letGo() {
        releaseGuard?.cancel()
        releaseGuard = nil
        guard heldFlags != nil else { return }
        heldFlags = nil
        guard let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
        else { return }
        up.type = .flagsChanged
        up.flags = []
        up.post(tap: .cghidEventTap)
    }

    private func armReleaseGuard() {
        releaseGuard?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.letGo() }
        releaseGuard = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: item)
    }

    private func press(_ key: CGKeyCode, flags: CGEventFlags) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
