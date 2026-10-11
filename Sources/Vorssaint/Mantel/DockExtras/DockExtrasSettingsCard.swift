// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import SwiftUI

/// One card on the Dock page for every installed DockDoor extra. Each extra
/// is its own hub switch; this card only shows the installed ones.
struct DockExtrasSettingsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.dockQuitClickEnabled) private var quitClick = true
    @AppStorage(DefaultsKey.dockScrollEnabled) private var scroll = true
    @AppStorage(DefaultsKey.dockScrollMediaVolume) private var mediaVolume = true
    @AppStorage(DefaultsKey.dockPreviewMassActionsEnabled) private var massActions = true
    @AppStorage(DefaultsKey.dockPreviewWindowButtonsEnabled) private var windowButtons = true
    @AppStorage(DefaultsKey.dockPreviewSwipeEnabled) private var swipe = true
    @AppStorage(DefaultsKey.dockPreviewShakeEnabled) private var shake = true
    @AppStorage(DefaultsKey.titleBarScrollEnabled) private var titleBarScroll = true

    static var hasInstalledExtra: Bool {
        [AppFeature.dockQuitClick, .dockScroll, .dockPreviewMassActions, .dockPreviewWindowButtons,
         .dockPreviewSwipe, .dockPreviewShake, .titleBarScroll]
            .contains { $0.isAvailable }
    }

    private var text: DockExtrasFeatureStrings { FeatureStrings.dockExtras(l10n.language) }

    var body: some View {
        SettingsCard(title: text.cardTitle) {
            if AppFeature.dockQuitClick.isAvailable {
                SettingsRow(symbol: "power", title: text.quitClickTitle, caption: text.quitClickCaption) {
                    Toggle(text.quitClickTitle, isOn: $quitClick).labelsHidden()
                }
            }
            if AppFeature.dockScroll.isAvailable {
                SettingsRow(symbol: "scroll", title: text.scrollTitle, caption: text.scrollCaption) {
                    Toggle(text.scrollTitle, isOn: $scroll).labelsHidden()
                }
                if scroll {
                    SettingsRow(symbol: "speaker.wave.2", title: text.scrollMediaVolume,
                                caption: text.scrollMediaVolumeCaption) {
                        Toggle(text.scrollMediaVolume, isOn: $mediaVolume).labelsHidden()
                    }
                }
            }
            if AppFeature.dockPreviewMassActions.isAvailable {
                SettingsRow(symbol: "rectangle.stack.badge.minus", title: text.massActionsTitle,
                            caption: text.massActionsCaption) {
                    Toggle(text.massActionsTitle, isOn: $massActions).labelsHidden()
                }
            }
            if AppFeature.dockPreviewWindowButtons.isAvailable {
                SettingsRow(symbol: "circle.grid.2x1", title: text.windowButtonsTitle,
                            caption: text.windowButtonsCaption) {
                    Toggle(text.windowButtonsTitle, isOn: $windowButtons).labelsHidden()
                }
            }
            if AppFeature.dockPreviewSwipe.isAvailable {
                SettingsRow(symbol: "hand.draw", title: text.swipeTitle, caption: text.swipeCaption) {
                    Toggle(text.swipeTitle, isOn: $swipe).labelsHidden()
                }
            }
            if AppFeature.dockPreviewShake.isAvailable {
                SettingsRow(symbol: "wind", title: text.shakeTitle, caption: text.shakeCaption) {
                    Toggle(text.shakeTitle, isOn: $shake).labelsHidden()
                }
            }
            if AppFeature.titleBarScroll.isAvailable {
                SettingsRow(symbol: "macwindow", title: text.titleBarTitle, caption: text.titleBarCaption) {
                    Toggle(text.titleBarTitle, isOn: $titleBarScroll).labelsHidden()
                }
            }
        }
        // The Dock tap's mask follows the three input extras.
        .onChange(of: quitClick) { _, _ in DockClickService.shared.syncWithPreferences() }
        .onChange(of: scroll) { _, _ in DockClickService.shared.syncWithPreferences() }
        .onChange(of: titleBarScroll) { _, _ in DockClickService.shared.syncWithPreferences() }
        .onChange(of: swipe) { _, _ in DockPreviewSwipe.shared.syncWithPreferences() }
    }
}
