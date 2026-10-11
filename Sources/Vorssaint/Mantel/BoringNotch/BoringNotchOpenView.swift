// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Layout from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// boringNotch/components/Notch/BoringHeader.swift, components/Tabs/TabSelectionView.swift,
// TabButton.swift; the player is in BoringNotchPlayerView.swift.

import SwiftUI

/// The two tabs of Boring Notch's open notch.
enum BoringNotchTab: String, CaseIterable {
    case home, shelf

    var symbol: String { self == .home ? "house.fill" : "tray.fill" }
}

/// The open island in the Boring Notch design: a header with the Home and
/// Shelf tabs on the camera's left, then the page. Reads Vorssaint's own
/// services (music, shelf); nothing here owns a system hook.
struct BoringNotchOpenView: View {
    @ObservedObject var service: NotchService
    @AppStorage(DefaultsKey.notchBoringTab) private var storedTab = BoringNotchTab.home.rawValue
    @Namespace private var tabCapsule

    private var tab: BoringNotchTab { BoringNotchTab(rawValue: storedTab) ?? .home }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: max(24, service.geometry.stripHeight))
            Group {
                switch tab {
                case .home: BoringNotchHomeView()
                case .shelf: shelf
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.scale(scale: 0.8, anchor: .top).combined(with: .opacity))
        }
        .padding(.horizontal, BoringNotchMetrics.openRadii.top + BoringNotchMetrics.openPadding)
        .padding(.bottom, BoringNotchMetrics.openPadding)
        .animation(.smooth(duration: 0.35), value: storedTab)
    }

    /// Tabs left of the camera, the camera's own width kept black, the right
    /// side left for slice 5c's battery and HUD (Boring Notch's header).
    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(BoringNotchTab.allCases, id: \.self) { item in
                    Button {
                        withAnimation(.smooth) { storedTab = item.rawValue }
                    } label: {
                        Image(systemName: item.symbol)
                            .padding(.horizontal, 15)
                            .frame(height: 26)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(item == tab ? Color.white : Color.gray)
                    .background {
                        Capsule()
                            .fill(item == tab ? Color(nsColor: .secondarySystemFill) : .clear)
                            .matchedGeometryEffect(id: "capsule", in: tabCapsule, isSource: item == tab)
                    }
                }
            }
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: service.geometry.cameraWidth)
            HStack(spacing: 4) {
                BoringNotchHeaderBattery(service: service)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(.headline, design: .rounded))
    }

    /// Slice 5a hosts Vorssaint's files page here; slice 5e brings Boring
    /// Notch's shelf.
    private var shelf: some View {
        ScrollView(.vertical, showsIndicators: false) {
            NotchFilesView(service: service)
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
