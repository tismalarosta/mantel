// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Combine
import Foundation

/// Whether the Mac is running shut: a Keep Awake session in closed-lid mode
/// with the lid actually down. Stay Online and Lid Pause both follow it.
/// Reads Keep Awake's own state and the lid sensor; it adds no power or lid
/// hook of its own (SPEC rule 4), the lid is polled only while closed-lid
/// mode is in effect.
final class LidClosedSession: ObservableObject {
    static let shared = LidClosedSession()

    @Published private(set) var lidShut = false

    /// Seconds between two lid reads while closed-lid mode is in effect: a
    /// lid opening resumes paused apps within this time.
    private static let lidPollInterval: TimeInterval = 2

    private var users = 0
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    private init() {}

    /// Called by each feature as it starts and stops; the session only
    /// watches while at least one of them is installed.
    func retain() {
        users += 1
        guard users == 1 else { return }
        let awake = KeepAwakeManager.shared
        Publishers.CombineLatest(awake.$isActive, awake.$clamshellActive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active, clamshell in self?.modeChanged(active && clamshell) }
            .store(in: &cancellables)
    }

    func release() {
        guard users > 0 else { return }
        users -= 1
        guard users == 0 else { return }
        cancellables.removeAll()
        modeChanged(false)
    }

    private func modeChanged(_ inEffect: Bool) {
        timer?.invalidate()
        timer = nil
        if inEffect {
            let timer = Timer(timeInterval: Self.lidPollInterval, repeats: true) { [weak self] _ in self?.readLid() }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        readLid()
    }

    private func readLid() {
        let shut = timer != nil && BrightnessService.lidClosed() == true
        if shut != lidShut { lidShut = shut }
    }
}
