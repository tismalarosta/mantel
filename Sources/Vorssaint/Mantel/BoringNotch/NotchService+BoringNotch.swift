// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import AppKit

extension NotchService {
    /// The notice's size in the Boring Notch design, for the view's choice.
    func boringNoticeSize(for notice: NotchNotice) -> CGSize? {
        BoringNotchHooks.noticeSize(event: notice.event, geometry: geometry)
    }
}

extension BoringNotchHooks {
    /// The app-only answers the hooks need, plugged in when the island syncs.
    static func installAppProviders() {
        playerBundleID = { NotchMusicService.shared.playback?.track.appBundleIdentifier }
    }
}
