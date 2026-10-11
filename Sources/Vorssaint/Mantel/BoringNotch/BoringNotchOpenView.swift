// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Layout from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// boringNotch/components/Notch/BoringHeader.swift, components/Tabs/TabSelectionView.swift,
// TabButton.swift; the player is in BoringNotchPlayerView.swift.

import SwiftUI

/// The open island in the Boring Notch design: a header with Home, Shelf
/// and Vorssaint's other pages as tabs (left of the camera, then right of it
/// when they do not fit), then the page. Reads Vorssaint's own services;
/// nothing here owns a system hook. The page follows Vorssaint's selected
/// section (`BoringNotchTabs.page`), so Vorssaint's shortcuts land on it.
struct BoringNotchOpenView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchBoringTab) private var storedTab = BoringNotchTab.home.rawValue
    @AppStorage(DefaultsKey.notchBoringHiddenTabs) private var hiddenTabs = BoringNotchTabs.stored(BoringNotchTabs.hiddenByDefault)
    @AppStorage(DefaultsKey.notchBoringMirrorShape) private var mirrorShape = BoringNotchMirrorShape.fallback.rawValue
    @Namespace private var tabCapsule

    private var tab: BoringNotchTab { BoringNotchTab(rawValue: storedTab) ?? .home }
    private var page: BoringNotchPage { BoringNotchTabs.page(selected: service.selected, storedTab: tab) }
    private var headerHeight: CGFloat { max(24, service.geometry.stripHeight) }

    /// Home and Shelf, then the Vorssaint pages shown as tabs.
    private var items: [BoringNotchPage] {
        [.home, .shelf] + BoringNotchTabs.visible(modules: service.modules, hidden: BoringNotchTabs.parse(hiddenTabs))
            .map { .module($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: headerHeight)
            Group {
                switch page {
                case .home: BoringNotchHomeView()
                case .shelf: shelf
                case .module(let module): vorssaintPage(module)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
        }
        .padding(.horizontal, BoringNotchMetrics.openRadii.top + BoringNotchMetrics.openPadding)
        .padding(.bottom, BoringNotchMetrics.openPadding)
        .animation(.smooth(duration: 0.35), value: page)
    }

    /// Boring Notch's header: the tabs left of the camera, the camera's own
    /// width kept black, the battery on the right. Tabs that do not fit on
    /// the left continue on the right, before the battery.
    private var header: some View {
        let inner = BoringNotchTabs.pageSize(island: service.expandedSize, headerHeight: headerHeight).width
        let side = max(0, (inner - service.geometry.cameraWidth) / 2)
        let all = items
        let layout = BoringNotchTabs.layout(count: all.count, left: side, right: side - 44)
        return HStack(spacing: 0) {
            tabRow(Array(all.prefix(layout.leftCount)), width: layout.width)
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: service.geometry.cameraWidth)
            HStack(spacing: 4) {
                tabRow(Array(all.dropFirst(layout.leftCount)), width: layout.width)
                Spacer(minLength: 0)
                BoringNotchHeaderBattery(service: service)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(.headline, design: .rounded))
    }

    @ViewBuilder private func tabRow(_ row: [BoringNotchPage], width: CGFloat) -> some View {
        if !row.isEmpty {
            HStack(spacing: 0) {
                ForEach(row, id: \.tabID) { item in
                    Button { choose(item) } label: {
                        Image(systemName: item.symbol)
                            .frame(width: width, height: 26)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(item == page ? Color.white : Color.gray)
                    .background {
                        Capsule()
                            .fill(item == page ? Color(nsColor: .secondarySystemFill) : .clear)
                            .matchedGeometryEffect(id: "capsule", in: tabCapsule, isSource: item == page)
                    }
                    .help(item.title(l10n.language))
                    .accessibilityLabel(item.title(l10n.language))
                }
            }
            .clipShape(Capsule())
        }
    }

    /// Home and Shelf are the design's own; the island also selects a section
    /// behind them, so a Vorssaint page left behind stops what it started.
    /// A Vorssaint tab selects its section, as Vorssaint's own navigation
    /// does. An island opened by hover still closes when the pointer leaves.
    private func choose(_ item: BoringNotchPage) {
        let target: NotchModule?
        switch item {
        case .home, .shelf:
            let chosen: BoringNotchTab = item == .shelf ? .shelf : .home
            withAnimation(.smooth) { storedTab = chosen.rawValue }
            let leaves = !BoringNotchTabs.native.contains(service.selected) || (chosen == .home && service.selected == .files)
            target = leaves ? BoringNotchTabs.anchor(for: chosen, modules: service.modules) : nil
        case .module(let module):
            target = module
        }
        guard let target, target != service.selected else { return }
        service.open(target, takeFocus: !service.openedByHover, feedback: false)
    }

    /// Boring Notch's shelf on Vorssaint's shelf service (slice 5e).
    private var shelf: some View {
        BoringNotchShelfView(service: service)
    }

    /// Vorssaint's own page, at the room Boring Notch's frame leaves it.
    @ViewBuilder private func vorssaintPage(_ module: NotchModule) -> some View {
        let size = BoringNotchTabs.pageSize(island: service.expandedSize, headerHeight: headerHeight)
        Group {
            switch module {
            case .timer: NotchTimerView(size: size)
            case .camera:
                let shape = BoringNotchMirrorShape.sanitized(mirrorShape)
                if shape.isBoringNotch { BoringNotchMirrorView(shape: shape, size: size) }
                else { NotchCameraView(size: size) }
            case .notifications: NotchNotificationsView(size: size)
            case .downloads: NotchDownloadsView(size: size)
            case .mixer: NotchMixerView(size: size)
            case .clipboard: NotchClipboardView(service: service, size: size)
            case .system: NotchSystemView(size: size) { service.showMetric($0) }
            case .tools: QuickLauncherView(notchSize: size)
            case .scratchpad: NotchScratchpadView(service: service)
            case .agents: NotchAgentsView(size: size)
            case .watch: NotchWatchView(size: size)
            case .music, .controls, .calendar, .files, .captures: EmptyView()
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .padding(.top, 4)
    }
}

private extension BoringNotchPage {
    var tabID: String {
        switch self {
        case .home: return "home"
        case .shelf: return "shelf"
        case .module(let module): return module.rawValue
        }
    }

    var symbol: String {
        switch self {
        case .home: return BoringNotchTab.home.symbol
        case .shelf: return BoringNotchTab.shelf.symbol
        case .module(let module): return module.symbol
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .home: return BoringNotchTabStrings.localized(language).home
        case .shelf: return BoringNotchTabStrings.localized(language).shelf
        case .module(let module): return module.title(language)
        }
    }
}

/// Boring Notch's closed music activity: the cover left of the camera, the
/// four bars right of it (`MusicLiveActivity` in ContentView.swift).
struct BoringNotchMusicActivity: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var music = NotchMusicService.shared
    @AppStorage(DefaultsKey.notchBoringVisualizer) private var visualizer = BoringNotchVisualizer.boringNotch.rawValue

    /// SPEC §3D: Boring Notch's bars, or Vorssaint's live equalizer.
    @ViewBuilder private var bars: some View {
        let playing = music.playback?.isPlaying == true
        if BoringNotchMusicSupport.visualizer(visualizer) == .vorssaint, AppFeature.notchLiveEqualizer.isAvailable {
            NotchLiveEqualizerBars(isPlaying: playing, bars: 4, barWidth: 2.5, height: 12, tint: .gray)
        } else {
            BoringNotchBars(isPlaying: playing)
        }
    }

    var body: some View {
        let side = max(0, service.geometry.stripHeight - 12)
        HStack(spacing: 0) {
            Group {
                if let artwork = music.artwork {
                    Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "music.note").font(.system(size: 10)).foregroundStyle(.gray)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: BoringNotchMetrics.closedArtRadius, style: .continuous))
            .frame(maxWidth: .infinity)
            Color.clear.frame(width: service.geometry.cameraWidth)
            bars
                .frame(width: 16, height: 12)
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
}

/// Boring Notch's four animated bars (AudioSpectrumView): random heights,
/// not read from the audio. Slice 5b offers Vorssaint's live equalizer as
/// the other choice.
struct BoringNotchBars: View {
    let isPlaying: Bool
    @State private var heights: [CGFloat] = [0.35, 0.6, 0.45, 0.7]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.gray.gradient)
                    .frame(width: 2.5)
                    .frame(height: 12 * (isPlaying ? heights[index] : 0.2))
            }
        }
        .frame(maxHeight: .infinity)
        .onReceive(Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                heights = heights.map { _ in CGFloat.random(in: 0.25...1) }
            }
        }
    }
}
