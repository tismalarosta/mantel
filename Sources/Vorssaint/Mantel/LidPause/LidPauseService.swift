// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import AppKit
import Combine
import Darwin
import os

/// Lid Pause: while the Mac runs shut (`LidClosedSession`), every Dock app
/// off the keep list is stopped (SIGSTOP) with all its processes, and
/// continued (SIGCONT) when the lid opens, the session ends, the feature is
/// switched off or Mantel quits. Paused ids are saved before the first
/// signal, so a crash is undone at the next launch. Which apps and processes:
/// `LidPauseSupport`.
final class LidPauseService: ObservableObject {
    static let shared = LidPauseService()
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "mantel",
                                    category: "lid-pause")

    /// Names of the apps paused right now, for the settings card.
    @Published private(set) var pausedApps: [String] = []

    private var installed = false
    private var cancellable: AnyCancellable?

    private init() {}

    var keepList: [String] {
        get { UserDefaults.standard.stringArray(forKey: DefaultsKey.lidPauseKeepList)
                ?? LidPauseSupport.defaultKeepList }
        set {
            objectWillChange.send()
            var seen = Set<String>()
            UserDefaults.standard.set(newValue.filter { seen.insert($0).inserted },
                                      forKey: DefaultsKey.lidPauseKeepList)
        }
    }

    func syncWithPreferences() {
        let wanted = AppFeature.lidPause.isAvailable
        guard wanted != installed else { return }
        installed = wanted
        if wanted {
            LidClosedSession.shared.retain()
            cancellable = LidClosedSession.shared.$lidShut
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] shut in shut ? self?.pause() : self?.resume() }
        } else {
            cancellable = nil
            LidClosedSession.shared.release()
            resume()
        }
    }

    // MARK: - Pause and resume

    private func pause() {
        let own = Bundle.main.bundleIdentifier
        let running = NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }
        let apps = running.map {
            LidPauseSupport.RunningApp(pid: $0.processIdentifier, bundleID: $0.bundleIdentifier,
                                       isRegular: $0.activationPolicy == .regular)
        }
        let toPause = LidPauseSupport.appsToPause(apps, keepList: keepList, ownBundleID: own)
        let pausedRoots = Set(toPause.map(\.pid))
        let keptRoots = Set(apps.map(\.pid)).subtracting(pausedRoots)
        let pids = LidPauseSupport.processTree(roots: pausedRoots, keptRoots: keptRoots,
                                               parents: Self.userProcessParents())
            .subtracting([getpid()])
        guard !pids.isEmpty else { return }
        // Saved before the first signal: a crash in between still resumes them.
        Self.savePaused(pids)
        for pid in pids { kill(pid, SIGSTOP) }
        let names = running.filter { pausedRoots.contains($0.processIdentifier) }
            .compactMap(\.localizedName)
        pausedApps = names.sorted()
        Self.log.info("paused \(pids.count) processes of \(names.count) apps")
    }

    private func resume() {
        Self.resumeLeftovers()
        pausedApps = []
    }

    /// Continues every process a previous pause saved. Called at launch and
    /// on quit whether or not the feature is installed, so nothing stays
    /// frozen after a crash or after the switch went off while Mantel was
    /// closed. SIGCONT on a process that is running, or gone, does nothing.
    static func resumeLeftovers() {
        let saved = UserDefaults.standard.array(forKey: DefaultsKey.lidPausePausedPIDs) as? [Int] ?? []
        guard !saved.isEmpty else { return }
        for pid in saved where pid > 1 { kill(pid_t(pid), SIGCONT) }
        UserDefaults.standard.removeObject(forKey: DefaultsKey.lidPausePausedPIDs)
        log.info("resumed \(saved.count) processes")
    }

    private static func savePaused(_ pids: Set<Int32>) {
        let saved = UserDefaults.standard.array(forKey: DefaultsKey.lidPausePausedPIDs) as? [Int] ?? []
        UserDefaults.standard.set(Array(Set(saved).union(pids.map(Int.init))).sorted(),
                                  forKey: DefaultsKey.lidPausePausedPIDs)
        UserDefaults.standard.synchronize()
    }

    /// (pid, parent pid) of every process this user owns.
    private static func userProcessParents() -> [Int32: Int32] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(getuid())]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return [:] }
        // Room for processes started between the two calls.
        size += size / 4
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.stride)
        guard sysctl(&mib, u_int(mib.count), &procs, &size, nil, 0) == 0 else { return [:] }
        let count = size / MemoryLayout<kinfo_proc>.stride
        var parents: [Int32: Int32] = [:]
        for proc in procs.prefix(count) { parents[proc.kp_proc.p_pid] = proc.kp_eproc.e_ppid }
        return parents
    }

    // MARK: - Settings helpers

    /// A bundle id's display name, for the keep list.
    static func appName(for bundleID: String) -> String {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let name = app.localizedName { return name }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    /// Dock apps running now that a pause would freeze, by bundle id.
    func runningPausable() -> [(id: String, name: String)] {
        let apps = NSWorkspace.shared.runningApplications.map {
            LidPauseSupport.RunningApp(pid: $0.processIdentifier, bundleID: $0.bundleIdentifier,
                                       isRegular: $0.activationPolicy == .regular)
        }
        return LidPauseSupport.appsToPause(apps, keepList: keepList, ownBundleID: Bundle.main.bundleIdentifier)
            .compactMap { $0.bundleID }
            .map { (id: $0, name: Self.appName(for: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
