// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// The pure half of Stay Online: what one check should do. When it runs is
/// `LidClosedSession`'s job.
/// Nothing here touches Wi-Fi, the keychain or Keep Awake.
///
/// macOS already rejoins known networks and, with "Ask to join hotspots" set
/// to Automatic, the iPhone hotspot. What it does not do: follow an order
/// (since Ventura it picks by its own history), or leave a working network
/// (or the hotspot) when a better one comes into range. Stay Online adds
/// those two, plus a Wi-Fi restart when the Mac has been offline too long.
enum NetworkFallbackSupport {
    /// Seconds between two checks while a session runs. A scan wakes the radio
    /// for a few seconds; once a minute keeps that cost small.
    static let checkInterval: TimeInterval = 60
    /// Offline this long before Wi-Fi is restarted: macOS usually rejoins on
    /// its own within half a minute, a restart only helps when it is stuck.
    static let offlineGrace: TimeInterval = 90
    /// At most one Wi-Fi restart per this many seconds, so a place with no
    /// network at all does not get a restart every check.
    static let restartCooldown: TimeInterval = 300
    /// A network that refused a join is left alone this long.
    static let failedJoinCooldown: TimeInterval = 600

    struct Snapshot: Equatable {
        var wifiPowered: Bool
        var online: Bool
        /// nil when not joined, or when Location is off (macOS hides names).
        var currentSSID: String?
        /// Network names the last scan saw; empty without Location.
        var visibleSSIDs: Set<String>
    }

    enum Action: Equatable {
        case none
        case join(String)
        case restartWiFi
    }

    /// One check. `priority` is the user's list, best first; the iPhone
    /// hotspot can sit in it like any network (usually last). Networks not in
    /// the list rank below every listed one.
    static func decide(_ snapshot: Snapshot, priority: [String],
                       failedJoins: [String: Date], offlineSince: Date?,
                       lastRestart: Date?, now: Date) -> Action {
        // Wi-Fi turned off is the user's choice; never turn it back on.
        guard snapshot.wifiPowered else { return .none }

        let currentRank = snapshot.currentSSID.flatMap { priority.firstIndex(of: $0) }
        // Joined but offline (no internet behind it): that network is no
        // better than none, so the next one in the list gets its turn.
        let best = priority.enumerated().first { _, ssid in
            snapshot.visibleSSIDs.contains(ssid)
                && !(ssid == snapshot.currentSSID && !snapshot.online)
                && (failedJoins[ssid].map { now.timeIntervalSince($0) >= failedJoinCooldown } ?? true)
        }
        if let best {
            // On a network ranked at least as high (a scan can miss the
            // joined one): stay.
            if snapshot.online, let currentRank, currentRank <= best.offset { return .none }
            return .join(best.element)
        }

        guard !snapshot.online, let offlineSince,
              now.timeIntervalSince(offlineSince) >= offlineGrace else { return .none }
        if let lastRestart, now.timeIntervalSince(lastRestart) < restartCooldown { return .none }
        // Nothing from the list in range: a restart lets macOS rejoin any
        // known network, or wake the iPhone hotspot through Instant Hotspot.
        return .restartWiFi
    }

    /// The saved list, cleaned: blanks and repeats dropped, order kept.
    static func sanitizedPriority(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw.compactMap { entry in
            let ssid = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ssid.isEmpty, seen.insert(ssid).inserted else { return nil }
            return ssid
        }
    }

    /// iPhone Personal Hotspot hands out 172.20.10.x, which tells the hotspot
    /// apart without Location permission (the status line uses it).
    static func isPersonalHotspotAddress(_ address: String) -> Bool {
        address.hasPrefix("172.20.10.")
    }
}
