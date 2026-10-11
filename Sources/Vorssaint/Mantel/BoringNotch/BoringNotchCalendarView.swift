// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// components/Calendar/BoringCalendar.swift (CalendarView, WheelPicker, EventListView,
// ReminderToggle, EmptyEventsView).

import EventKit
import SwiftUI

/// Localized strings for the calendar panel. English and French are
/// written; other languages read English.
struct BoringNotchCalendarStrings {
    let allDay, noEvents, enjoy, allowReminders, calendarAccess: String
    let reminders, remindersCaption, hideCompleted, markDone, markOpen: String

    static func localized(_ language: AppLanguage) -> BoringNotchCalendarStrings { language == .fr ? .fr : .enUS }

    static let enUS = BoringNotchCalendarStrings(
        allDay: "All-day", noEvents: "No events", enjoy: "Enjoy your free time!",
        allowReminders: "Show reminders", calendarAccess: "Allow Calendar for Mantel to see your events.",
        reminders: "Reminders in the calendar", remindersCaption: "Tick a reminder off from the notch; Reminders keeps it done.",
        hideCompleted: "Hide completed reminders", markDone: "Mark as complete", markOpen: "Mark as incomplete")

    static let fr = BoringNotchCalendarStrings(
        allDay: "Journée", noEvents: "Aucun événement", enjoy: "Profitez de votre temps libre\u{00A0}!",
        allowReminders: "Afficher les rappels", calendarAccess: "Autorisez Calendrier pour Mantel afin de voir vos événements.",
        reminders: "Rappels dans le calendrier", remindersCaption: "Cochez un rappel depuis l’encoche, Rappels le garde terminé.",
        hideCompleted: "Masquer les rappels terminés", markDone: "Marquer comme terminé", markOpen: "Marquer comme à faire")
}

/// Boring Notch's calendar in Home's right column: the month and a strip of
/// days, then the day's events (Vorssaint's calendar service) and reminders.
struct BoringNotchCalendarView: View {
    @ObservedObject private var calendar = NotchCalendarService.shared
    @ObservedObject private var reminders = BoringNotchRemindersService.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var selected = Date()

    private var text: BoringNotchCalendarStrings { BoringNotchCalendarStrings.localized(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(selected.formatted(.dateTime.month(.abbreviated)))
                        .font(.title3).fontWeight(.semibold).foregroundStyle(.white)
                    Text(selected.formatted(.dateTime.year()))
                        .font(.title3).fontWeight(.light).foregroundStyle(Color(white: 0.65))
                }
                BoringNotchDayStrip(selected: $selected)
            }
            list
        }
        .onAppear { load(selected) }
        .onChange(of: selected) { _, day in load(day) }
        .onDisappear {
            calendar.showMonth(nil)
            reminders.hide()
        }
    }

    private func load(_ day: Date) {
        calendar.showMonth(Calendar.current.isDate(day, equalTo: Date(), toGranularity: .month) ? nil : day)
        reminders.show(day: day)
    }

    @ViewBuilder private var list: some View {
        let events = NotchCalendarSupport.isEnabled()
            ? BoringNotchCalendarSupport.events(calendar.events, on: selected) : []
        let showsReminders = BoringNotchCalendarSupport.remindersEnabled()
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                if NotchCalendarSupport.isEnabled(), permissions.calendarAccess != .fullAccess {
                    Text(text.calendarAccess).font(.caption).foregroundStyle(.gray)
                }
                ForEach(events, id: \.id) { eventRow($0) }
                if showsReminders {
                    if reminders.isAuthorized {
                        ForEach(reminders.reminders) { reminderRow($0) }
                    } else if reminders.status == .notDetermined {
                        Button(text.allowReminders) { reminders.requestAccess() }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(Color.accentColor)
                    }
                }
                if events.isEmpty && (!showsReminders || reminders.reminders.isEmpty) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text.noEvents).font(.subheadline).foregroundStyle(.white)
                        Text(text.enjoy).font(.caption).foregroundStyle(.gray)
                    }
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func color(_ tint: NotchCalendarColor) -> Color {
        Color(red: tint.red, green: tint.green, blue: tint.blue)
    }

    /// EventListView's event row: calendar colour bar, title, place, times.
    private func eventRow(_ event: NotchCalendarEvent) -> some View {
        let ended = event.end < Date() && Calendar.current.isDateInToday(event.start)
        return HStack(alignment: .top, spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5).fill(color(event.color)).frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.callout).fontWeight(.medium).foregroundStyle(.white).lineLimit(2)
                if !event.location.isEmpty {
                    Text(event.location).font(.caption).foregroundStyle(Color(white: 0.65)).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                if event.allDay {
                    Text(text.allDay).fontWeight(.medium).foregroundStyle(.white)
                } else {
                    Text(event.start, style: .time).foregroundStyle(.white)
                    Text(event.end, style: .time).foregroundStyle(Color(white: 0.65))
                }
            }
            .font(.caption)
            .frame(minWidth: 44, alignment: .trailing)
        }
        .opacity(ended ? 0.6 : 1)
    }

    /// EventListView's reminder row, with Boring Notch's ring toggle.
    private func reminderRow(_ reminder: BoringNotchReminder) -> some View {
        HStack(spacing: 8) {
            Button { reminders.setCompleted(!reminder.completed, for: reminder) } label: {
                ZStack {
                    Circle().strokeBorder(color(reminder.color), lineWidth: 2).frame(width: 14, height: 14)
                    if reminder.completed { Circle().fill(color(reminder.color)).frame(width: 8, height: 8) }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(reminder.completed ? text.markOpen : text.markDone)
            Text(reminder.title).font(.callout).foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 0)
            if let due = reminder.due {
                if reminder.hasTime {
                    Text(due, style: .time).font(.caption).foregroundStyle(.white)
                } else {
                    Text(text.allDay).font(.caption).fontWeight(.medium).foregroundStyle(.white)
                }
            }
        }
        .opacity(reminder.completed ? 0.4 : 1)
    }
}

/// Boring Notch's WheelPicker: a strip of days that snaps to the one chosen.
struct BoringNotchDayStrip: View {
    @Binding var selected: Date
    @State private var days = BoringNotchCalendarSupport.stripDays(around: Date())

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(days, id: \.self) { day in
                        dayButton(day).id(day)
                    }
                }
                .padding(.horizontal, 20)
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                         .init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
            .onAppear { proxy.scrollTo(Calendar.current.startOfDay(for: selected), anchor: .center) }
            .onChange(of: selected) { _, day in
                withAnimation { proxy.scrollTo(Calendar.current.startOfDay(for: day), anchor: .center) }
            }
        }
        .frame(height: 50)
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selected)
        let isToday = Calendar.current.isDateInToday(day)
        return Button { selected = day } label: {
            VStack(spacing: 6) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white : Color(white: 0.65))
                ZStack {
                    Circle().fill(isToday ? Color.accentColor : .clear).frame(width: 20, height: 20)
                    Text(day.formatted(.dateTime.day()))
                        .font(.body).fontWeight(.medium)
                        .foregroundStyle(isSelected ? Color.white : Color(white: isToday ? 0.9 : 0.65))
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.white.opacity(0.12) : .clear))
        }
        .buttonStyle(.plain)
    }
}

/// The reminders options, in the Design card while Boring Notch is the design.
struct BoringNotchCalendarOptions: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchBoringReminders) private var showReminders = true
    @AppStorage(DefaultsKey.notchBoringHideCompleted) private var hideCompleted = true

    private var text: BoringNotchCalendarStrings { BoringNotchCalendarStrings.localized(l10n.language) }

    var body: some View {
        SettingsRow(symbol: "checklist", title: text.reminders, caption: text.remindersCaption) {
            Toggle(text.reminders, isOn: $showReminders).labelsHidden()
        }
        if showReminders {
            SettingsRow(symbol: "eye.slash", title: text.hideCompleted) {
                Toggle(text.hideCompleted, isOn: $hideCompleted).labelsHidden()
            }
        }
    }
}
