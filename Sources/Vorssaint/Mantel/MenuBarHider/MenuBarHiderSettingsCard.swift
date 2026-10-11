// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Options follow Ice by Jordan Baird (github.com/jordanbaird/Ice, GPL-3.0).

import SwiftUI

/// The menu bar hider's card on the General page, next to the menu bar
/// icon's own settings. Ice's options as Vorssaint rows (SPEC §2: no foreign
/// settings window).
struct MenuBarHiderSettingsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = MenuBarHiderService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.menuBarHiderEnabled) private var enabled = false
    @AppStorage(DefaultsKey.menuBarHiderShowOnClick) private var showOnClick = true
    @AppStorage(DefaultsKey.menuBarHiderShowOnHover) private var showOnHover = false
    @AppStorage(DefaultsKey.menuBarHiderHoverDelay) private var hoverDelay = MenuBarHiderSupport.defaultHoverDelay
    @AppStorage(DefaultsKey.menuBarHiderShowOnScroll) private var showOnScroll = true
    @AppStorage(DefaultsKey.menuBarHiderAutoRehide) private var autoRehide = true
    @AppStorage(DefaultsKey.menuBarHiderRehideStrategy) private var strategy = MenuBarRehideStrategy.fallback.rawValue
    @AppStorage(DefaultsKey.menuBarHiderRehideInterval)
    private var rehideInterval = MenuBarHiderSupport.defaultRehideInterval
    @AppStorage(DefaultsKey.menuBarHiderAlwaysHiddenEnabled) private var alwaysHiddenEnabled = false
    @AppStorage(DefaultsKey.menuBarHiderShortcutsEnabled) private var shortcutsEnabled = false

    private var text: MenuBarHiderFeatureStrings { FeatureStrings.menuBarHider(l10n.language) }

    var body: some View {
        SettingsCard(title: text.title) {
            SettingsRow(symbol: "chevron.left", title: text.enable, caption: text.enableCaption) {
                Toggle(text.enable, isOn: $enabled).labelsHidden()
            }
            if enabled {
                Text(text.arrangeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, settingsRowTextInset)
                SettingsRow(symbol: "cursorarrow.click", title: text.showOnClick, caption: text.showOnClickCaption) {
                    Toggle(text.showOnClick, isOn: $showOnClick).labelsHidden()
                }
                SettingsRow(symbol: "cursorarrow.rays", title: text.showOnHover,
                            caption: showOnHover ? hoverDelayLabel : nil) {
                    Toggle(text.showOnHover, isOn: $showOnHover).labelsHidden()
                }
                if showOnHover {
                    Slider(value: hoverDelayBinding, in: MenuBarHiderSupport.hoverDelayRange, step: 0.1)
                        .padding(.leading, settingsRowTextInset)
                }
                if (showOnClick || showOnHover) && !permissions.accessibility {
                    Text(text.needsAccessibility)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.leading, settingsRowTextInset)
                    PermissionRow(kind: .accessibility)
                }
                SettingsRow(symbol: "scroll", title: text.showOnScroll, caption: text.showOnScrollCaption) {
                    Toggle(text.showOnScroll, isOn: $showOnScroll).labelsHidden()
                }
                SettingsRow(symbol: "eye.slash", title: text.autoRehide,
                            caption: autoRehide && selectedStrategy == .timed ? intervalLabel : nil) {
                    HStack(spacing: 8) {
                        if autoRehide {
                            Picker(text.autoRehide, selection: strategyBinding) {
                                ForEach(MenuBarRehideStrategy.allCases, id: \.self) { option in
                                    Text(text.label(for: option)).tag(option)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                        Toggle(text.autoRehide, isOn: $autoRehide).labelsHidden()
                    }
                }
                if autoRehide && selectedStrategy == .timed {
                    Slider(value: intervalBinding, in: MenuBarHiderSupport.rehideIntervalRange, step: 1)
                        .padding(.leading, settingsRowTextInset)
                }
                SettingsRow(symbol: "chevron.compact.left", title: text.alwaysHidden,
                            caption: text.alwaysHiddenCaption) {
                    Toggle(text.alwaysHidden, isOn: $alwaysHiddenEnabled).labelsHidden()
                }
                SettingsRow(symbol: "keyboard", title: text.shortcuts, caption: text.shortcutsCaption) {
                    Toggle(text.shortcuts, isOn: $shortcutsEnabled).labelsHidden()
                }
                if shortcutsEnabled {
                    ShortcutPreferenceRow(role: .menuBarHiderToggleHidden, isEnabled: shortcutsEnabled) {
                        MenuBarHiderService.shared.syncWithPreferences()
                    }
                    if alwaysHiddenEnabled {
                        ShortcutPreferenceRow(role: .menuBarHiderToggleAlwaysHidden, isEnabled: shortcutsEnabled) {
                            MenuBarHiderService.shared.syncWithPreferences()
                        }
                    }
                    if service.shortcutRegistrationFailed {
                        Text(l10n.s.shortcutUnavailable)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.leading, settingsRowTextInset)
                    }
                }
            }
        }
        .onChange(of: syncKey) { _, _ in MenuBarHiderService.shared.syncWithPreferences() }
    }

    /// Every stored choice the service reads, so one change resyncs it.
    private var syncKey: String {
        [String(enabled), String(showOnClick), String(showOnHover), String(hoverDelay), String(showOnScroll),
         String(autoRehide), strategy, String(rehideInterval), String(alwaysHiddenEnabled),
         String(shortcutsEnabled)].joined(separator: "|")
    }

    private var selectedStrategy: MenuBarRehideStrategy { MenuBarRehideStrategy.sanitized(strategy) }

    private var strategyBinding: Binding<MenuBarRehideStrategy> {
        Binding(get: { selectedStrategy }, set: { strategy = $0.rawValue })
    }

    private var hoverDelayBinding: Binding<Double> {
        Binding(get: { MenuBarHiderSupport.sanitizedHoverDelay(hoverDelay) },
                set: { hoverDelay = MenuBarHiderSupport.sanitizedHoverDelay($0) })
    }

    private var intervalBinding: Binding<Double> {
        Binding(get: { MenuBarHiderSupport.sanitizedRehideInterval(rehideInterval) },
                set: { rehideInterval = MenuBarHiderSupport.sanitizedRehideInterval($0) })
    }

    private var hoverDelayLabel: String {
        let seconds = MenuBarHiderSupport.sanitizedHoverDelay(hoverDelay)
        return String(format: text.hoverDelayFormat, String(format: "%.1f", locale: .current, seconds))
    }

    private var intervalLabel: String {
        String(format: text.rehideIntervalFormat, Int(MenuBarHiderSupport.sanitizedRehideInterval(rehideInterval)))
    }
}
