// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Behaviour from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// components/Calendar/BoringCalendar.swift (WheelPicker, EventListView).

import Foundation

/// One reminder as the calendar panel shows it: display values only.
struct BoringNotchReminder: Identifiable, Equatable {
    let id: String
    let title: String
    let due: Date?
    let hasTime: Bool
    let completed: Bool
    let color: NotchCalendarColor
}

/// The pure half of Boring Notch's calendar panel: days, ordering, choices.
enum BoringNotchCalendarSupport {
    /// Days the strip offers on either side of today (Boring Notch scrolls a
    /// few weeks around it).
    static let stripRadius = 14

    static func remindersEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.notchBoringReminders)
    }

    /// Boring Notch hides completed reminders by default.
    static func hidesCompletedReminders(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.notchBoringHideCompleted)
    }

    static func dayInterval(_ day: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    /// The strip's days, today in the middle.
    static func stripDays(around today: Date, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: today)
        return (-stripRadius...stripRadius).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Vorssaint's events that touch `day`, all-day ones first, then by start.
    static func events(_ events: [NotchCalendarEvent], on day: Date,
                       calendar: Calendar = .current) -> [NotchCalendarEvent] {
        let interval = dayInterval(day, calendar: calendar)
        return events
            .filter { $0.start < interval.end && $0.end > interval.start }
            .sorted { ($0.allDay ? 0 : 1, $0.start) < ($1.allDay ? 0 : 1, $1.start) }
    }

    /// Open reminders before done ones, each by due time; the done ones
    /// left out when Boring Notch's "hide completed" is on.
    static func ordered(_ reminders: [BoringNotchReminder], hidingCompleted: Bool) -> [BoringNotchReminder] {
        reminders
            .filter { !(hidingCompleted && $0.completed) }
            .sorted { lhs, rhs in
                if lhs.completed != rhs.completed { return !lhs.completed }
                return (lhs.due ?? .distantFuture) < (rhs.due ?? .distantFuture)
            }
    }

    /// The right column's first panel: the calendar while nothing plays,
    /// Up Next while music plays (Matisse, 2026-10-11). A choice made with
    /// the toggle wins while it is still offered.
    static func panel(chosen: BoringNotchSidePanel?, available: [BoringNotchSidePanel],
                      isPlaying: Bool) -> BoringNotchSidePanel? {
        if let chosen, available.contains(chosen) { return chosen }
        let preferred: BoringNotchSidePanel = isPlaying ? .upNext : .calendar
        return available.contains(preferred) ? preferred : available.first
    }
}
