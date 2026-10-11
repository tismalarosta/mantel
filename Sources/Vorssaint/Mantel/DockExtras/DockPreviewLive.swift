// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// After DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// Utilities/Window Management/LiveWindowCapture.swift (live previews).

import Foundation

/// C1: while a Dock preview is open, its thumbnails are captured again a few
/// times a second, so videos and changing windows move in the preview.
/// DockDoor streams each window through ScreenCaptureKit; this repeats
/// Vorssaint's own capture instead (one capture path, SPEC rule 4), at the
/// chosen rate, and only while the panel is up. It costs battery, which is
/// why it is off by default (dropped for Matisse on 2026-10-11).
final class DockPreviewLive {
    static let shared = DockPreviewLive()

    private var timer: Timer?

    private init() {}

    /// Called when the Dock preview opens for an app.
    func begin() {
        stop()
        guard DockExtrasSupport.livePreviewsOn else { return }
        let fps = DockExtrasSupport.sanitizedLiveFPS(
            UserDefaults.standard.integer(forKey: DefaultsKey.dockLivePreviewFPS))
        let timer = Timer(timeInterval: 1 / Double(fps), repeats: true) { [weak self] _ in
            let service = DockPreviewService.shared
            guard service.isVisible, DockExtrasSupport.livePreviewsOn else { return self?.stop() ?? () }
            service.refreshVisiblePreviews()
        }
        timer.tolerance = 0.25 / Double(fps)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
