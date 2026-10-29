// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// The pure half of Lid Pause: which apps freeze while the lid is shut, and
/// which processes belong to each. Nothing here sends a signal.
///
/// Only Dock apps are paused (menu bar helpers, daemons and system processes
/// never are), each with every process it started (Chrome's helpers, an
/// Electron app's renderers). An app on the keep list keeps its whole tree
/// running, so Claude's own `claude` and `node` children keep working.
enum LidPauseSupport {
    /// Kept running by default; the user edits this list.
    static let defaultKeepList = [
        "com.anthropic.claudefordesktop",
        "com.google.Chrome",
        "com.openai.codex",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "com.matisse.regis",
    ]

    /// Never paused, whatever the list says: pausing these freezes the
    /// desktop, the session or Mantel itself.
    static let protectedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
        "com.apple.loginwindow",
        "com.apple.ActivityMonitor",
        "com.apple.systempreferences",
    ]

    struct RunningApp: Equatable {
        var pid: Int32
        var bundleID: String?
        /// A Dock app (`NSApplication.ActivationPolicy.regular`).
        var isRegular: Bool
    }

    /// The apps to pause. Mantel itself, apps without a bundle id and
    /// anything not in the Dock are always left alone.
    static func appsToPause(_ apps: [RunningApp], keepList: [String], ownBundleID: String?) -> [RunningApp] {
        let keep = Set(keepList).union(protectedBundleIDs)
        return apps.filter { app in
            guard app.isRegular, let id = app.bundleID, id != ownBundleID else { return false }
            return !keep.contains(id)
        }
    }

    /// Every process under `roots`, roots included, from a (pid, parent pid)
    /// table. Processes under a kept app are excluded even when a paused app
    /// is further up (a terminal started from Finder keeps its shell).
    static func processTree(roots: Set<Int32>, keptRoots: Set<Int32>,
                            parents: [Int32: Int32]) -> Set<Int32> {
        var children: [Int32: [Int32]] = [:]
        for (pid, parent) in parents where pid != parent { children[parent, default: []].append(pid) }
        var result = Set<Int32>()
        var stack = Array(roots)
        while let pid = stack.popLast() {
            // pid 0 and 1 are the kernel and launchd: never, nor what hangs under them.
            guard pid > 1, !keptRoots.contains(pid), result.insert(pid).inserted else { continue }
            stack.append(contentsOf: children[pid] ?? [])
        }
        return result
    }
}
