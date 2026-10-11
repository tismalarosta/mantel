// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import SwiftUI

/// Type Clipboard's section on the Clipboard settings page, laid out like
/// Paste as plain text right above it.
struct TypeClipboardSettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = TypeClipboardService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.typeClipboardEnabled) private var enabled = true
    @AppStorage(DefaultsKey.typeClipboardSpeed) private var speed = TypeClipboardSpeed.fallback.rawValue
    @AppStorage(DefaultsKey.typeClipboardCustomDelay)
    private var customDelay = TypeClipboardSupport.defaultCustomDelay
    @AppStorage(DefaultsKey.typeClipboardEscapeStops) private var escapeStops = true

    private var text: TypeClipboardFeatureStrings {
        FeatureStrings.typeClipboard(l10n.language)
    }

    var body: some View {
        Section {
            Toggle(text.enable, isOn: $enabled)
                .onChange(of: enabled) { _, _ in
                    TypeClipboardService.shared.syncWithPreferences()
                }
            Text(text.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            ShortcutPreferenceRow(role: .typeClipboard, isEnabled: enabled) {
                TypeClipboardService.shared.syncWithPreferences()
            }
            if enabled, service.shortcutRegistrationFailed {
                Text(l10n.s.shortcutUnavailable)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Picker(text.speedTitle, selection: speedBinding) {
                ForEach(TypeClipboardSpeed.allCases, id: \.self) { option in
                    Text(text.label(for: option)).tag(option)
                }
            }
            .disabled(!enabled)
            if TypeClipboardSpeed.sanitized(speed) == .custom {
                HStack {
                    Slider(value: customDelayBinding,
                           in: Double(TypeClipboardSupport.customDelayRange.lowerBound)
                               ... Double(TypeClipboardSupport.customDelayRange.upperBound),
                           step: 1)
                    Text(String(format: text.customDelayFormat,
                                TypeClipboardSupport.sanitizedCustomDelay(customDelay)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 130, alignment: .trailing)
                }
                .disabled(!enabled)
            }
            Toggle(text.escapeStops, isOn: $escapeStops)
                .disabled(!enabled)
            Text(text.escapeStopsCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            if enabled, !permissions.accessibility {
                PermissionRow(kind: .accessibility)
            }
        } header: {
            Text(text.title)
        }
        .settingsFormSectionAnchor(.typeClipboard)
    }

    private var speedBinding: Binding<TypeClipboardSpeed> {
        Binding(
            get: { TypeClipboardSpeed.sanitized(speed) },
            set: { speed = $0.rawValue }
        )
    }

    private var customDelayBinding: Binding<Double> {
        Binding(
            get: { Double(TypeClipboardSupport.sanitizedCustomDelay(customDelay)) },
            set: { customDelay = TypeClipboardSupport.sanitizedCustomDelay(Int($0.rounded())) }
        )
    }
}
