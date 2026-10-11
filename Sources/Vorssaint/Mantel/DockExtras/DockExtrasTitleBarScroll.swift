// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// DockDoor/Utilities/DockObserver.swift (handleTitleBarScroll, refreshTitleBarCache).

import AppKit

/// C8: scroll up on the front window's title bar to maximize it, down to
/// centre it. A guest of Vorssaint's Dock Click tap like C7 (one scroll tap,
/// SPEC rule 4), and the window moves through Vorssaint's Window Layout
/// actions, so the frame settling and Restore history are Vorssaint's.
///
/// The tap callback must stay short, so the front window's title bar is read
/// off the main run loop's next turn and kept for a second (DockDoor's cache):
/// the first scroll after that only schedules the read and goes on to the app.
final class DockExtrasTitleBarScroll {
    static let shared = DockExtrasTitleBarScroll()

    private struct Target {
        let pid: pid_t
        let windowID: CGWindowID
        let frame: CGRect
        let titleBar: CGRect
        let readAt: CFAbsoluteTime
    }

    private static let cacheLifetime: CFAbsoluteTime = 1.0
    private var target: Target?
    private var readScheduled = false
    private var lastAction: CFAbsoluteTime = 0
    /// The window this extra last maximized from a smaller size: scrolling
    /// down on it puts it back (Window Layout's Restore) instead of centring
    /// a window that already fills the screen.
    private var maximizedWindowID: CGWindowID?

    private init() {}

    /// Runs inside the tap callback; true keeps the scroll from the app.
    func handle(_ event: CGEvent) -> Bool {
        guard DockExtrasSupport.titleBarScrollOn else { return false }
        let now = CFAbsoluteTimeGetCurrent()
        if let cached = target, now - cached.readAt > Self.cacheLifetime { target = nil }
        guard let cached = target else {
            scheduleRead()
            return false
        }
        guard cached.titleBar.contains(event.location) else { return false }
        let decision = DockExtrasSupport.titleBarDecision(
            deltaX: event.getDoubleValueField(.scrollWheelEventDeltaAxis2),
            deltaY: event.getDoubleValueField(.scrollWheelEventDeltaAxis1),
            natural: NSEvent(cgEvent: event)?.isDirectionInvertedFromDevice ?? false,
            isMomentum: event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0,
            sinceLastAction: now - lastAction)
        switch decision {
        case .pass: return false
        case .swallow: return true
        case .maximize, .centre:
            lastAction = now
            DispatchQueue.main.async { [weak self] in self?.perform(decision, on: cached) }
            return true
        }
    }

    private func perform(_ decision: DockExtrasSupport.TitleBarDecision, on cached: Target) {
        // Window Layout acts on the front app's focused window: only go on
        // while that is still the window the pointer was over.
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == cached.pid,
              WindowActivator.focusedWindowID(for: cached.pid) == cached.windowID else { return }
        target = nil
        let layout = WindowLayoutService.shared
        if decision == .maximize {
            let wasFilling = visibleFrame(around: cached.frame).map {
                DockExtrasSupport.fills(cached.frame, visibleFrame: $0)
            } ?? false
            if case .success = layout.apply(.maximize), !wasFilling {
                maximizedWindowID = cached.windowID
            }
            return
        }
        if maximizedWindowID == cached.windowID {
            maximizedWindowID = nil
            if case .success = layout.apply(.restore) { return }
        }
        layout.apply(.center)
    }

    private func scheduleRead() {
        guard !readScheduled else { return }
        readScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            readScheduled = false
            target = readFrontWindow()
        }
    }

    /// The front app's focused window, only when it has a real title bar:
    /// a close button, not minimized, not full screen. A full-screen window
    /// has no title bar to scroll on, and its top edge is page content.
    private func readFrontWindow() -> Target? {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.activationPolicy == .regular else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(axApp, 0.25)
        guard let window = element(axApp, kAXFocusedWindowAttribute as String),
              string(window, kAXRoleAttribute as String) == kAXWindowRole as String,
              !bool(window, kAXMinimizedAttribute as String),
              !bool(window, "AXFullScreen"),
              let frame = frame(of: window),
              let closeButton = element(window, kAXCloseButtonAttribute as String),
              let buttonFrame = self.frame(of: closeButton),
              let windowID = AXWindowResolver.windowID(for: window)
        else { return nil }
        return Target(pid: app.processIdentifier, windowID: windowID, frame: frame,
                      titleBar: DockExtrasSupport.titleBarRect(window: frame, closeButton: buttonFrame),
                      readAt: CFAbsoluteTimeGetCurrent())
    }

    /// The usable area of the screen holding most of the window, top-left
    /// coordinates like the window's frame.
    private func visibleFrame(around frame: CGRect) -> CGRect? {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        let screens = NSScreen.screens.map {
            (frame: DockExtrasSupport.topLeftRect(fromAppKit: $0.frame, primaryScreenHeight: primaryHeight),
             visible: DockExtrasSupport.topLeftRect(fromAppKit: $0.visibleFrame, primaryScreenHeight: primaryHeight))
        }
        let best = screens.max { lhs, rhs in
            let a = lhs.frame.intersection(frame), b = rhs.frame.intersection(frame)
            return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
        }
        return best?.visible
    }

    // MARK: - Accessibility reads

    private func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func bool(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }
}
