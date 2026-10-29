// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// Stay Online's pure rules: what each check does.
enum NetworkFallbackTests {
    typealias Support = NetworkFallbackSupport

    static func run(_ suite: TestSuite) {
        joins(suite)
        restarts(suite)
        lists(suite)
    }

    private static let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private static let list = ["Home", "Office", "Matisse iPhone"]

    private static func snap(online: Bool = true, current: String? = nil,
                             visible: Set<String> = [], powered: Bool = true) -> Support.Snapshot {
        Support.Snapshot(wifiPowered: powered, online: online, currentSSID: current, visibleSSIDs: visible)
    }

    private static func decide(_ s: Support.Snapshot, failed: [String: Date] = [:],
                               offlineFor: TimeInterval? = nil, restartedAgo: TimeInterval? = nil) -> Support.Action {
        Support.decide(s, priority: list, failedJoins: failed,
                       offlineSince: offlineFor.map { now.addingTimeInterval(-$0) },
                       lastRestart: restartedAgo.map { now.addingTimeInterval(-$0) }, now: now)
    }

    private static func joins(_ suite: TestSuite) {
        suite.expect(decide(snap(current: "Home", visible: ["Home", "Office"])) == .none,
                     "on the best network, nothing happens")
        suite.expect(decide(snap(current: "Matisse iPhone", visible: ["Office", "Matisse iPhone"]))
                        == .join("Office"),
                     "on the hotspot with a listed Wi-Fi in range, it moves to the Wi-Fi")
        suite.expect(decide(snap(current: "Office", visible: ["Home", "Office"])) == .join("Home"),
                     "a higher network in range wins over a working lower one")
        suite.expect(decide(snap(current: "Home", visible: ["Office"])) == .none,
                     "a scan that misses the joined network does not trigger a downgrade")
        suite.expect(decide(snap(current: "Cafe", visible: ["Cafe", "Office"])) == .join("Office"),
                     "an unlisted network ranks below every listed one")
        suite.expect(decide(snap(current: "Cafe", visible: ["Cafe"])) == .none,
                     "on a working unlisted network with nothing listed around, it stays")
        suite.expect(decide(snap(online: false, current: "Home", visible: ["Home", "Office"]), offlineFor: 5)
                        == .join("Office"),
                     "joined but no internet: the next listed network gets its turn")
        suite.expect(decide(snap(online: false, visible: ["Matisse iPhone"]), offlineFor: 5)
                        == .join("Matisse iPhone"),
                     "offline with only the hotspot broadcasting: it joins the hotspot")
        suite.expect(decide(snap(current: "Office", visible: ["Home", "Office"]),
                            failed: ["Home": now.addingTimeInterval(-60)]) == .none,
                     "a network that just refused a join is skipped")
        suite.expect(decide(snap(current: "Office", visible: ["Home", "Office"]),
                            failed: ["Home": now.addingTimeInterval(-Support.failedJoinCooldown)]) == .join("Home"),
                     "after its cooldown a refused network is tried again")
        suite.expect(decide(snap(powered: false), offlineFor: 1_000) == .none,
                     "Wi-Fi switched off by the user stays off")
    }

    private static func restarts(_ suite: TestSuite) {
        suite.expect(decide(snap(online: false), offlineFor: Support.offlineGrace - 1) == .none,
                     "a short drop is left to macOS")
        suite.expect(decide(snap(online: false), offlineFor: Support.offlineGrace) == .restartWiFi,
                     "offline past the grace with nothing listed in range: Wi-Fi restarts")
        suite.expect(decide(snap(online: false), offlineFor: 1_000, restartedAgo: 60) == .none,
                     "never two restarts inside the cooldown")
        suite.expect(decide(snap(online: false), offlineFor: 1_000, restartedAgo: Support.restartCooldown)
                        == .restartWiFi,
                     "a new restart once the cooldown has passed")
        suite.expect(decide(snap(online: true), offlineFor: 1_000) == .none,
                     "online means no restart, whatever the clock says")
        suite.expect(decide(snap(online: false)) == .none,
                     "no offline start time yet, no restart")
    }

    private static func lists(_ suite: TestSuite) {
        suite.expect(Support.sanitizedPriority([" Home ", "", "Office", "Home", "\n"]) == ["Home", "Office"],
                     "the saved list drops blanks and repeats and keeps the order")
        suite.expect(Support.isPersonalHotspotAddress("172.20.10.4"), "172.20.10.x is the iPhone hotspot")
        suite.expect(!Support.isPersonalHotspotAddress("172.20.100.4"), "a look-alike range is not")
        suite.expect(!Support.isPersonalHotspotAddress("192.168.1.10"), "a home router is not")
    }
}
