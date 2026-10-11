// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Options after Boring Notch's settings (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// components/Settings/SettingsView.swift (gesture control, mirror shape, show on lock screen).

import SwiftUI

/// Strings for slice 5f: the tabs, the mirror, gestures and the lock screen.
/// English and French are written; other languages read the English text.
struct BoringNotchTabStrings {
    let home: String
    let shelf: String
    let mirror: String
    let tabs: String
    let tabsCaption: String
    let mirrorShape: String
    let mirrorRectangle: String
    let mirrorCircle: String
    let mirrorVorssaint: String
    let gestures: String
    let gesturesCaption: String
    let closeGesture: String
    let sensitivity: String
    let sensitivityHigh: String
    let sensitivityMedium: String
    let sensitivityLow: String
    let lockScreen: String
    let lockScreenCaption: String

    static func localized(_ language: AppLanguage) -> BoringNotchTabStrings { language == .fr ? .fr : .enUS }

    static let enUS = BoringNotchTabStrings(
        home: "Home", shelf: "Shelf", mirror: "Mirror",
        tabs: "Tabs",
        tabsCaption: "Vorssaint pages shown as tabs after Home and Shelf. Only pages the island has can be tabs.",
        mirrorShape: "Mirror", mirrorRectangle: "Rounded square", mirrorCircle: "Circle", mirrorVorssaint: "Vorssaint",
        gestures: "Gestures",
        gesturesCaption: "Boring Notch: swipe down on the notch to open it, up to close it. Vorssaint: its own swipes, sideways skips tracks.",
        closeGesture: "Swipe up to close",
        sensitivity: "Sensitivity", sensitivityHigh: "High", sensitivityMedium: "Medium", sensitivityLow: "Low",
        lockScreen: "Lock screen",
        lockScreenCaption: "Boring Notch: only the notch, with the cover and bars. Vorssaint: also its player under the clock and its activities. Applies when the island shows on the lock screen.")

    static let fr = BoringNotchTabStrings(
        home: "Accueil", shelf: "Étagère", mirror: "Miroir",
        tabs: "Onglets",
        tabsCaption: "Pages de Vorssaint affichées en onglets après Accueil et Étagère. Seules les pages de l’île peuvent devenir des onglets.",
        mirrorShape: "Miroir", mirrorRectangle: "Carré arrondi", mirrorCircle: "Cercle", mirrorVorssaint: "Vorssaint",
        gestures: "Gestes",
        gesturesCaption: "Boring Notch : glisser vers le bas sur l’encoche pour l’ouvrir, vers le haut pour la fermer. Vorssaint : ses propres gestes, de côté pour changer de morceau.",
        closeGesture: "Glisser vers le haut pour fermer",
        sensitivity: "Sensibilité", sensitivityHigh: "Haute", sensitivityMedium: "Moyenne", sensitivityLow: "Basse",
        lockScreen: "Écran verrouillé",
        lockScreenCaption: "Boring Notch : l’encoche seule, avec la pochette et les barres. Vorssaint : aussi son lecteur sous l’horloge et ses activités. S’applique quand l’île s’affiche sur l’écran verrouillé.")
}

/// Slice 5f's options in the Design card: which Vorssaint pages are tabs,
/// the mirror's shape, and the pick-one choices for gestures and the lock
/// screen (SPEC §3D).
struct BoringNotchMoreOptions: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchBoringHiddenTabs) private var hiddenTabs = BoringNotchTabs.stored(BoringNotchTabs.hiddenByDefault)
    @AppStorage(DefaultsKey.notchBoringMirrorShape) private var mirrorShape = BoringNotchMirrorShape.fallback.rawValue
    @AppStorage(DefaultsKey.notchBoringGestureStyle) private var gestureStyle = BoringNotchGestureStyle.fallback.rawValue
    @AppStorage(DefaultsKey.notchBoringCloseGesture) private var closeGesture = true
    @AppStorage(DefaultsKey.notchBoringGestureSensitivity) private var sensitivity = BoringNotchGestureSensitivity.fallback.rawValue
    @AppStorage(DefaultsKey.notchBoringLockScreenStyle) private var lockScreen = BoringNotchLockScreenStyle.fallback.rawValue

    private var text: BoringNotchTabStrings { BoringNotchTabStrings.localized(l10n.language) }

    var body: some View {
        tabOptions
        if NotchSupport.modules().contains(.camera) {
            SettingsRow(symbol: "web.camera", title: text.mirrorShape) {
                Picker(text.mirrorShape, selection: $mirrorShape) {
                    Text(text.mirrorRectangle).tag(BoringNotchMirrorShape.rectangle.rawValue)
                    Text(text.mirrorCircle).tag(BoringNotchMirrorShape.circle.rawValue)
                    Text(text.mirrorVorssaint).tag(BoringNotchMirrorShape.vorssaint.rawValue)
                }
                .labelsHidden().fixedSize()
            }
        }
        if AppFeature.notchGestures.isAvailable {
            SettingsRow(symbol: "hand.draw", title: text.gestures, caption: text.gesturesCaption) {
                Picker(text.gestures, selection: $gestureStyle) {
                    Text("Boring Notch").tag(BoringNotchGestureStyle.boringNotch.rawValue)
                    Text("Vorssaint").tag(BoringNotchGestureStyle.vorssaint.rawValue)
                }
                .labelsHidden().fixedSize()
            }
            if BoringNotchGestureStyle.sanitized(gestureStyle) == .boringNotch {
                SettingsRow(symbol: "dial.medium", title: text.sensitivity) {
                    Picker(text.sensitivity, selection: $sensitivity) {
                        Text(text.sensitivityHigh).tag(BoringNotchGestureSensitivity.high.rawValue)
                        Text(text.sensitivityMedium).tag(BoringNotchGestureSensitivity.medium.rawValue)
                        Text(text.sensitivityLow).tag(BoringNotchGestureSensitivity.low.rawValue)
                    }
                    .labelsHidden().fixedSize()
                }
                SettingsRow(symbol: "arrow.up", title: text.closeGesture) {
                    Toggle(text.closeGesture, isOn: $closeGesture).labelsHidden().toggleStyle(.switch)
                }
            }
        }
        SettingsRow(symbol: "lock", title: text.lockScreen, caption: text.lockScreenCaption) {
            Picker(text.lockScreen, selection: $lockScreen) {
                Text("Boring Notch").tag(BoringNotchLockScreenStyle.boringNotch.rawValue)
                Text("Vorssaint").tag(BoringNotchLockScreenStyle.vorssaint.rawValue)
            }
            .labelsHidden().fixedSize()
        }
        .onChange(of: lockScreen) { _, _ in NotchService.shared.syncWithPreferences() }
    }

    /// One button per page the island has, lit while it is a tab.
    @ViewBuilder private var tabOptions: some View {
        let available = BoringNotchTabs.extras.filter(NotchSupport.modules().contains)
        if !available.isEmpty {
            let hidden = BoringNotchTabs.parse(hiddenTabs)
            SettingsRow(symbol: "rectangle.split.3x1", title: text.tabs, caption: text.tabsCaption) { EmptyView() }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6, alignment: .leading)],
                      alignment: .leading, spacing: 6) {
                ForEach(available, id: \.self) { module in
                    Toggle(isOn: Binding(get: { !hidden.contains(module) }, set: { shown in
                        var next = hidden
                        if shown { next.remove(module) } else { next.insert(module) }
                        hiddenTabs = BoringNotchTabs.stored(next)
                    })) {
                        Label(module.title(l10n.language), systemImage: module.symbol)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .toggleStyle(.button)
                }
            }
            .padding(.leading, settingsRowTextInset)
        }
    }
}
