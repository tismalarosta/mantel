// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// What makes a build Mantel rather than Vorssaint. Vorssaint's TRADEMARKS.md
/// asks forks not to pass as Vorssaint; Mantel also stays off Vorssaint's own
/// servers: screenshot and recording share links upload to
/// screenshots.vorssaint.com, and feedback goes there too.
enum MantelBuild {
    static let bundleIdentifier = "app.mantel.dev"
    static let repository = URL(string: "https://github.com/tismalarosta/mantel")!
    static var issues: URL { repository.appendingPathComponent("issues/new") }

    static func isMantel(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> Bool {
        bundleIdentifier == Self.bundleIdentifier
    }

    static var isMantel: Bool { isMantel() }

    /// At launch: the two share-link switches stay off in Mantel, whatever a
    /// copied Vorssaint preference said.
    static func applyAtLaunch(defaults: UserDefaults = .standard) {
        guard isMantel else { return }
        defaults.set(false, forKey: DefaultsKey.screenshotSharingEnabled)
        defaults.set(false, forKey: DefaultsKey.recorderSharingEnabled)
    }
}
