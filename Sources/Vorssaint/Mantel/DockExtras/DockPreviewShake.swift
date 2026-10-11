// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// Views/Hover Window/WindowPreviewHoverContainer.swift (checkForShakeGesture,
// minimizeAllWindows with a kept window).

import AppKit

/// C4: shaking a preview card while dragging it out of the panel minimizes
/// the app's other windows and brings the shaken one forward (DockDoor's
/// "minimize all except this one"). It rides on Vorssaint's own drag to
/// place: `DockPreviewService` reports the drag here and stops it on a shake.
final class DockPreviewShake {
    static let shared = DockPreviewShake()

    private var item: SwitcherItem?
    private var points: [CGPoint] = []
    private var lastSample: CFAbsoluteTime = 0

    private init() {}

    func begin(_ item: SwitcherItem) {
        self.item = DockExtrasSupport.shakeOn ? item : nil
        points.removeAll()
        lastSample = 0
    }

    /// The dragged item once the pointer has shaken it, nil otherwise.
    func shaken(at pointer: CGPoint) -> SwitcherItem? {
        guard let item, DockExtrasSupport.shakeOn else { return nil }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastSample > DockExtrasSupport.shakeSampleInterval else { return nil }
        lastSample = now
        points.append(pointer)
        if points.count > DockExtrasSupport.shakeSampleLimit {
            points.removeFirst(points.count - DockExtrasSupport.shakeSampleLimit)
        }
        guard DockExtrasSupport.isShake(points) else { return nil }
        self.item = nil
        points.removeAll()
        return item
    }

    /// Minimizes every other window of the panel; full-screen windows own
    /// their Space and are left as they are.
    func minimizeOthers(than kept: SwitcherItem, in windows: [SwitcherItem]) {
        for window in windows where window.id != kept.id && !window.isMinimized && !window.isFullscreen {
            guard let windowID = window.windowID else { continue }
            WindowActivator.setWindowMinimized(true, windowID: windowID, pid: window.windowOwnerPID)
        }
    }
}
