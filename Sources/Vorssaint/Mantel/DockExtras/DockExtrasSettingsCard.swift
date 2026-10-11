// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import AppKit
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
    @AppStorage(DefaultsKey.titleBarScrollSwitchesDesktop) private var titleBarDesktop = false
    @AppStorage(DefaultsKey.trackpadSwitcherSwipeEnabled) private var switcherSwipe = true
    @AppStorage(DefaultsKey.trackpadSwitcherSwipeFingers) private var swipeFingers = 3
    @AppStorage(DefaultsKey.trackpadSwitcherSwipeDirection) private var swipeDirection = "horizontal"
    @AppStorage(DefaultsKey.dockActiveIndicatorEnabled) private var indicator = true
    @AppStorage(DefaultsKey.dockActiveIndicatorStyle) private var indicatorStyle = "line"
    @AppStorage(DefaultsKey.dockLockEnabled) private var dockLock = true
    @AppStorage(DefaultsKey.dockLockScreen) private var dockLockScreen = ""
    @AppStorage(DefaultsKey.dockAppCardsEnabled) private var appCards = true
    @AppStorage(DefaultsKey.dockFolderPopEnabled) private var folderPop = true
    @AppStorage(DefaultsKey.dockLivePreviewsEnabled) private var livePreviews = true
    @AppStorage(DefaultsKey.dockLivePreviewFPS) private var liveFPS = 5

    static var hasInstalledExtra: Bool {
        [AppFeature.dockQuitClick, .dockScroll, .dockPreviewMassActions, .dockPreviewWindowButtons,
         .dockPreviewSwipe, .dockPreviewShake, .titleBarScroll,
         .trackpadSwitcherSwipe, .dockActiveIndicator, .dockLock, .dockAppCards,
         .dockFolderPop, .dockLivePreviews]
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
                if titleBarScroll {
                    SettingsRow(symbol: "rectangle.split.3x1", title: text.titleBarDesktop,
                                caption: text.titleBarDesktopCaption) {
                        Toggle(text.titleBarDesktop, isOn: $titleBarDesktop).labelsHidden()
                    }
                }
            }
            if AppFeature.trackpadSwitcherSwipe.isAvailable {
                SettingsRow(symbol: "hand.draw.fill", title: text.switcherSwipeTitle,
                            caption: AppFeature.switcher.isAvailable
                                ? text.switcherSwipeCaption : text.switcherNeeded) {
                    Toggle(text.switcherSwipeTitle, isOn: $switcherSwipe).labelsHidden()
                }
                if switcherSwipe {
                    SettingsRow(symbol: "hand.raised.fingers.spread", title: text.switcherSwipeFingers) {
                        Picker(text.switcherSwipeFingers, selection: $swipeFingers) {
                            Text("3").tag(3)
                            Text("4").tag(4)
                        }
                        .labelsHidden().pickerStyle(.segmented).fixedSize()
                    }
                    SettingsRow(symbol: "arrow.left.and.right", title: text.switcherSwipeDirection) {
                        Picker(text.switcherSwipeDirection, selection: $swipeDirection) {
                            Text(text.horizontal).tag("horizontal")
                            Text(text.vertical).tag("vertical")
                        }
                        .labelsHidden().pickerStyle(.segmented).fixedSize()
                    }
                }
            }
            if AppFeature.dockActiveIndicator.isAvailable {
                SettingsRow(symbol: "smallcircle.filled.circle", title: text.indicatorTitle,
                            caption: text.indicatorCaption) {
                    Toggle(text.indicatorTitle, isOn: $indicator).labelsHidden()
                }
                if indicator {
                    SettingsRow(symbol: "paintbrush", title: text.indicatorStyle) {
                        Picker(text.indicatorStyle, selection: $indicatorStyle) {
                            Text(text.styleLine).tag("line")
                            Text(text.styleDots).tag("dots")
                        }
                        .labelsHidden().fixedSize()
                    }
                }
            }
            if AppFeature.dockAppCards.isAvailable {
                SettingsRow(symbol: "music.note.list", title: text.appCardsTitle, caption: text.appCardsCaption) {
                    Toggle(text.appCardsTitle, isOn: $appCards).labelsHidden()
                }
            }
            if AppFeature.dockFolderPop.isAvailable {
                SettingsRow(symbol: "folder.badge.gearshape", title: text.folderPopTitle, caption: text.folderPopCaption) {
                    Toggle(text.folderPopTitle, isOn: $folderPop).labelsHidden()
                }
            }
            if AppFeature.dockLivePreviews.isAvailable {
                SettingsRow(symbol: "play.rectangle", title: text.livePreviewsTitle, caption: text.livePreviewsCaption) {
                    Toggle(text.livePreviewsTitle, isOn: $livePreviews).labelsHidden()
                }
                if livePreviews {
                    SettingsRow(symbol: "speedometer", title: text.livePreviewsRate) {
                        Picker(text.livePreviewsRate, selection: $liveFPS) {
                            ForEach(DockExtrasSupport.liveFPSChoices, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .labelsHidden().pickerStyle(.segmented).fixedSize()
                    }
                }
            }
            if AppFeature.dockLock.isAvailable {
                SettingsRow(symbol: "lock.display", title: text.dockLockTitle, caption: text.dockLockCaption) {
                    Toggle(text.dockLockTitle, isOn: $dockLock).labelsHidden()
                }
                if dockLock {
                    SettingsRow(symbol: "display.2", title: text.dockLockScreen) {
                        Picker(text.dockLockScreen, selection: $dockLockScreen) {
                            Text(text.menuBarScreen).tag("")
                            ForEach(NSScreen.screens, id: \.self) { screen in
                                if let id = DockLock.uuid(of: screen) {
                                    Text(screen.localizedName).tag(id)
                                }
                            }
                        }
                        .labelsHidden().fixedSize()
                    }
                }
            }
        }
        // The Dock tap's mask follows the three input extras.
        .onChange(of: quitClick) { _, _ in DockClickService.shared.syncWithPreferences() }
        .onChange(of: scroll) { _, _ in DockClickService.shared.syncWithPreferences() }
        .onChange(of: titleBarScroll) { _, _ in DockClickService.shared.syncWithPreferences() }
        .onChange(of: swipe) { _, _ in DockPreviewSwipe.shared.syncWithPreferences() }
        .onChange(of: switcherSwipe) { _, _ in TrackpadSwitcherSwipe.shared.syncWithPreferences() }
        .onChange(of: indicator) { _, _ in DockActiveIndicator.shared.syncWithPreferences() }
        .onChange(of: indicatorStyle) { _, _ in DockActiveIndicator.shared.syncWithPreferences() }
        .onChange(of: appCards) { _, on in if !on { DockAppCard.shared.hide() } }
        .onChange(of: folderPop) { _, on in if !on { DockFolderPop.shared.hide() } }
        .onChange(of: livePreviews) { _, on in if !on { DockPreviewLive.shared.stop() } }
        .onChange(of: dockLock) { _, _ in
            DockLock.shared.syncWithPreferences()
            DockClickService.shared.syncWithPreferences()
        }
        .onChange(of: dockLockScreen) { _, _ in
            DockLock.shared.syncWithPreferences()
            DockClickService.shared.syncWithPreferences()
        }
    }
}
