// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// Lid Pause's pure rules: which apps freeze and which processes go with them.
enum LidPauseTests {
    typealias Support = LidPauseSupport

    static func run(_ suite: TestSuite) {
        selection(suite)
        trees(suite)
    }

    private static func app(_ pid: Int32, _ id: String?, regular: Bool = true) -> Support.RunningApp {
        Support.RunningApp(pid: pid, bundleID: id, isRegular: regular)
    }

    private static func selection(_ suite: TestSuite) {
        let apps = [
            app(10, "com.google.Chrome"), app(11, "com.tinyspeck.slackmacgap"),
            app(12, "com.apple.finder"), app(13, "app.mantel.dev"),
            app(14, "com.example.menubar", regular: false), app(15, nil),
            app(16, "com.apple.mail"),
        ]
        let paused = Support.appsToPause(apps, keepList: Support.defaultKeepList, ownBundleID: "app.mantel.dev")
        suite.expect(paused.map(\.pid) == [11, 16], "only Dock apps off the keep list pause: Slack and Mail")
        suite.expect(Support.appsToPause([app(12, "com.apple.finder")], keepList: [], ownBundleID: nil).isEmpty,
                     "Finder never pauses, even with an empty keep list")
        suite.expect(Support.appsToPause([app(13, "app.mantel.dev")], keepList: [], ownBundleID: "app.mantel.dev").isEmpty,
                     "Mantel never pauses itself")
        suite.expect(Support.appsToPause([app(14, "com.example.menubar", regular: false)], keepList: [],
                                         ownBundleID: nil).isEmpty,
                     "menu bar helpers and background agents are left alone")
        suite.expect(Support.defaultKeepList.contains("com.anthropic.claudefordesktop")
                        && Support.defaultKeepList.contains("com.google.Chrome"),
                     "Claude and Chrome keep running by default")
    }

    private static func trees(_ suite: TestSuite) {
        // 1 launchd > 20 Slack > 21 helper > 22 its child; 1 > 30 Claude > 31 node;
        // 20 Slack > 40 a terminal the user kept > 41 its shell.
        let parents: [Int32: Int32] = [20: 1, 21: 20, 22: 21, 30: 1, 31: 30, 40: 20, 41: 40, 1: 0]
        suite.expect(Support.processTree(roots: [20], keptRoots: [30], parents: parents) == [20, 21, 22, 40, 41],
                     "a paused app takes all its helpers and their children")
        suite.expect(Support.processTree(roots: [20], keptRoots: [30, 40], parents: parents) == [20, 21, 22],
                     "a kept app's tree stays running even under a paused one")
        suite.expect(!Support.processTree(roots: [20], keptRoots: [], parents: parents).contains(31),
                     "Claude's node child is never in another app's tree")
        suite.expect(Support.processTree(roots: [1, 0], keptRoots: [], parents: parents).isEmpty,
                     "launchd and the kernel are never paused, nor is everything under them")
        suite.expect(Support.processTree(roots: [30], keptRoots: [30], parents: parents).isEmpty,
                     "a root that is also kept pauses nothing")
    }
}
