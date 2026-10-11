// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// Views/Hover Window/WindowPreview Supporting/TrackpadGestureModifier.swift and
// WindowPreviewInteractionModifier.swift (swipe toward / away from the Dock).

import AppKit
import SwiftUI

/// C3 on one preview card: swiping toward the Dock minimizes its window,
/// away from the Dock opens it filling the screen. The card only reports
/// hover; one shared watcher reads the swipe.
struct DockPreviewSwipeModifier: ViewModifier {
    let window: SwitcherItem
    let orientation: DockPreviewOrientation
    /// The panel's own actions, so a pinned panel and the hover panel each
    /// keep their own bookkeeping.
    let onToggleMinimized: () -> Void
    let onOpen: () -> Void

    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                DockPreviewSwipe.shared.enter(DockPreviewSwipe.Target(
                    window: window, orientation: orientation,
                    onToggleMinimized: onToggleMinimized, onOpen: onOpen))
            } else {
                DockPreviewSwipe.shared.leave(window.id)
            }
        }
    }
}

/// Reads trackpad swipes over the hovered preview card. Scrolls over the
/// panel reach this app, so a local monitor sees them: no event tap (SPEC
/// rule 4), and nothing at all is watched while the extra is off.
final class DockPreviewSwipe {
    static let shared = DockPreviewSwipe()

    struct Target {
        let window: SwitcherItem
        let orientation: DockPreviewOrientation
        let onToggleMinimized: () -> Void
        let onOpen: () -> Void
    }

    private var monitor: Any?
    private var target: Target?
    private var totalX = 0.0
    private var totalY = 0.0
    private var natural = false
    private var isSwiping = false
    /// Backup end of a swipe, as in DockDoor: not every swipe sends `.ended`.
    private var endTimer: Timer?

    private init() {}

    func syncWithPreferences() {
        guard !DockExtrasSupport.swipeOn else { return }
        target = nil
        reset()
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    func enter(_ target: Target) {
        guard DockExtrasSupport.swipeOn else { return }
        if self.target?.window.id != target.window.id { reset() }
        self.target = target
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event)
                return event
            }
        }
    }

    func leave(_ id: SwitcherItem.ID) {
        guard target?.window.id == id else { return }
        target = nil
        reset()
    }

    private func handle(_ event: NSEvent) {
        guard target != nil, event.hasPreciseScrollingDeltas else { return }
        switch event.phase {
        case .began:
            reset()
            isSwiping = true
            natural = event.isDirectionInvertedFromDevice
        case .changed:
            totalX += event.scrollingDeltaX
            totalY += event.scrollingDeltaY
        case .ended:
            finish()
        case .cancelled:
            reset()
        default:
            // Momentum after the fingers lift belongs to no swipe.
            return
        }
        endTimer?.invalidate()
        endTimer = isSwiping
            ? Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in self?.finish() }
            : nil
    }

    private func finish() {
        guard isSwiping, let target else { return reset() }
        let direction = DockExtrasSupport.swipeDirection(totalX: totalX, totalY: totalY, natural: natural)
        reset()
        switch DockExtrasSupport.swipeAction(direction, dock: target.orientation) {
        case .none:
            break
        case .minimize:
            guard !target.window.isMinimized, !target.window.isFullscreen else { return }
            target.onToggleMinimized()
        case .maximize:
            self.target = nil
            target.onOpen()
            Self.maximizeOnceFocused(target.window, attempt: 0)
        }
    }

    private func reset() {
        endTimer?.invalidate()
        endTimer = nil
        totalX = 0
        totalY = 0
        isSwiping = false
    }

    /// DockDoor fills the screen with the window it opened. Vorssaint's
    /// Window Layout does the placing (and keeps Restore), but it acts on
    /// the focused window, so this waits for the activation to land.
    private static func maximizeOnceFocused(_ window: SwitcherItem, attempt: Int) {
        guard attempt < 10, let windowID = window.windowID else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            // Window Layout reads the front app's focused window: the app's
            // own pid, which a helper process owning the window can differ from.
            let pid = window.pid
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
               WindowActivator.focusedWindowID(for: pid) == windowID {
                WindowLayoutService.shared.apply(.maximize)
            } else {
                maximizeOnceFocused(window, attempt: attempt + 1)
            }
        }
    }
}
