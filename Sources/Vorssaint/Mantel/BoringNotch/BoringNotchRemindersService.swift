// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// boringNotch/managers/CalendarManager.swift (reminders, setReminderCompleted).

import AppKit
import Combine
import EventKit

/// EventKit reminders stay on one actor, like Vorssaint's calendar reader.
/// Vorssaint reads events only, so reminders are Mantel's: one more store,
/// no system hook (EventKit allows several stores per app).
private actor BoringNotchRemindersReader {
    private lazy var store = EKEventStore()

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToReminders()) ?? false
    }

    func reminders(on day: Date) async -> [BoringNotchReminder] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }
        let interval = BoringNotchCalendarSupport.dayInterval(day)
        let calendars = store.calendars(for: .reminder)
        let open = store.predicateForIncompleteReminders(withDueDateStarting: interval.start,
                                                         ending: interval.end, calendars: calendars)
        let done = store.predicateForCompletedReminders(withCompletionDateStarting: interval.start,
                                                        ending: interval.end, calendars: calendars)
        let found = await fetch(open) + fetch(done)
        var seen = Set<String>()
        return found.compactMap { reminder in
            let id = reminder.calendarItemIdentifier
            guard seen.insert(id).inserted else { return nil }
            let components = reminder.dueDateComponents
            let due = components.flatMap { Calendar.current.date(from: $0) } ?? reminder.completionDate
            let color = reminder.calendar.cgColor.flatMap { NSColor(cgColor: $0)?.usingColorSpace(.sRGB) }
                .map { NotchCalendarColor(red: $0.redComponent, green: $0.greenComponent, blue: $0.blueComponent) }
                ?? .fallback
            return BoringNotchReminder(id: id, title: reminder.title ?? "", due: due,
                                       hasTime: components?.hour != nil, completed: reminder.isCompleted,
                                       color: color)
        }
    }

    func setCompleted(_ completed: Bool, id: String) -> Bool {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess,
              let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        reminder.isCompleted = completed
        return (try? store.save(reminder, commit: true)) != nil
    }

    private func fetch(_ predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
        }
    }
}

/// The reminders of the day shown in Boring Notch's calendar panel, and
/// ticking them off (Boring Notch writes completion back to Reminders too).
final class BoringNotchRemindersService: ObservableObject {
    static let shared = BoringNotchRemindersService()

    @Published private(set) var reminders: [BoringNotchReminder] = []
    @Published private(set) var status = EKEventStore.authorizationStatus(for: .reminder)

    private let reader = BoringNotchRemindersReader()
    private var day = Date()
    private var task: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    var isAuthorized: Bool { status == .fullAccess }

    private init() {}

    /// Only while the panel shows: nothing is read or watched otherwise.
    func show(day: Date) {
        self.day = day
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil,
                                                              queue: .main) { [weak self] _ in self?.refresh() }
        }
        refresh()
    }

    func hide() {
        task?.cancel()
        task = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    func requestAccess() {
        Task { @MainActor in
            _ = await reader.requestAccess()
            status = EKEventStore.authorizationStatus(for: .reminder)
            refresh()
        }
    }

    func setCompleted(_ completed: Bool, for reminder: BoringNotchReminder) {
        // Shown at once; the store change refreshes from the source after.
        reminders = reminders.map {
            $0.id == reminder.id
                ? BoringNotchReminder(id: $0.id, title: $0.title, due: $0.due, hasTime: $0.hasTime,
                                      completed: completed, color: $0.color)
                : $0
        }
        Task { _ = await reader.setCompleted(completed, id: reminder.id) }
    }

    private func refresh() {
        status = EKEventStore.authorizationStatus(for: .reminder)
        task?.cancel()
        guard BoringNotchCalendarSupport.remindersEnabled(), isAuthorized else {
            reminders = []
            return
        }
        let requested = day
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            let found = await self.reader.reminders(on: requested)
            guard !Task.isCancelled, Calendar.current.isDate(requested, inSameDayAs: self.day) else { return }
            let hideDone = BoringNotchCalendarSupport.hidesCompletedReminders()
            self.reminders = BoringNotchCalendarSupport.ordered(found, hidingCompleted: hideDone)
        }
    }
}
