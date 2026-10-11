// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// boringNotch/components/Notch/NotchHomeView.swift (MusicPlayerView, AlbumArtView,
// MusicControlsView, VolumeControlView, MusicSliderView, CustomSlider).

import AppKit
import SwiftUI

/// Boring Notch's Home tab: the player on the left, and on the right the
/// side panel Boring Notch keeps for its calendar, here Vorssaint's Up Next
/// and, when chosen, Vorssaint's lyrics. All of it reads Vorssaint's music
/// service (one Now Playing bridge, SPEC rule 4).
struct BoringNotchHomeView: View {
    @ObservedObject private var music = NotchMusicService.shared
    @AppStorage(DefaultsKey.notchBoringLyricsStyle) private var lyricsStyle = BoringNotchLyricsStyle.boringNotch.rawValue
    @AppStorage(DefaultsKey.notchBoringSidePanel) private var sidePanel = BoringNotchSidePanel.upNext.rawValue

    private var panels: [BoringNotchSidePanel] {
        guard music.playback != nil else { return [] }
        var list: [BoringNotchSidePanel] = []
        if NotchQueueSupport.isEnabled() { list.append(.upNext) }
        if NotchLyricsSupport.isEnabled(),
           BoringNotchMusicSupport.lyricsStyle(lyricsStyle) == .vorssaint { list.append(.lyrics) }
        return list
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BoringNotchPlayer()
            if let playback = music.playback, !panels.isEmpty {
                sideColumn(playback: playback)
                    .frame(width: 215)
            }
        }
        .padding(.top, 4)
    }

    private func sideColumn(playback: NotchPlayback) -> some View {
        let current = panels.contains(BoringNotchSidePanel(rawValue: sidePanel) ?? .upNext)
            ? BoringNotchSidePanel(rawValue: sidePanel) ?? .upNext : panels[0]
        return VStack(alignment: .leading, spacing: 4) {
            if panels.count > 1 {
                HStack(spacing: 6) {
                    ForEach(panels, id: \.self) { panel in
                        Button { sidePanel = panel.rawValue } label: {
                            Image(systemName: panel.symbol)
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 22, height: 16)
                                .background(Capsule().fill(panel == current ? Color.white.opacity(0.14) : .clear))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(panel == current ? Color.white : Color.gray)
                    }
                }
            }
            Group {
                switch current {
                case .upNext: NotchQueueView(playback: playback)
                case .lyrics: NotchLyricsView(playback: playback)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
        }
    }
}

/// What the right column shows. Stored by raw value.
enum BoringNotchSidePanel: String, CaseIterable {
    case upNext, lyrics

    var symbol: String { self == .upNext ? "list.bullet" : "quote.bubble" }
}

/// Boring Notch's music player: art with its glow, the song, the seek bar
/// and the arrangeable buttons.
struct BoringNotchPlayer: View {
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var shuffle = NotchShuffleService.shared
    @AppStorage(DefaultsKey.notchBoringMusicSlots) private var storedSlots = BoringNotchMusicSlot.stored(BoringNotchMusicSlot.defaultLayout)
    @AppStorage(DefaultsKey.notchBoringMusicSlotCount) private var slotCount = 5
    @AppStorage(DefaultsKey.notchBoringLyricsStyle) private var lyricsStyle = BoringNotchLyricsStyle.boringNotch.rawValue

    private var isPlaying: Bool { music.playback?.isPlaying == true }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            art.padding(5)
            VStack(alignment: .leading, spacing: 0) {
                songInfo
                if let playback = music.playback, playback.duration > 0 {
                    BoringNotchSeekBar(playback: playback) { _ = music.send(.seek($0)) }
                        .padding(.top, 5)
                        .frame(height: 36)
                }
                Spacer(minLength: 0)
                slots
            }
            .padding(.top, 10)
            .padding(.leading, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .onAppear { shuffle.refresh(for: music.playback) }
        .onChange(of: music.playback?.track.title) { _, _ in shuffle.refresh(for: music.playback) }
    }

    // MARK: Art (AlbumArtView)

    private var art: some View {
        ZStack {
            if let artwork = music.artwork {
                // Boring Notch's lighting: the cover, blown up, turned and blurred.
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: BoringNotchMetrics.openArtRadius, style: .continuous))
                    .scaleEffect(x: 1.3, y: 1.4)
                    .rotationEffect(.degrees(92))
                    .blur(radius: 40)
                    .opacity(isPlaying ? 0.5 : 0)
            }
            Group {
                if let artwork = music.artwork {
                    Image(nsImage: artwork).resizable().aspectRatio(1, contentMode: .fill)
                } else {
                    ZStack {
                        Color.white.opacity(0.08)
                        Image(systemName: "music.note").font(.system(size: 28)).foregroundStyle(.gray)
                    }
                }
            }
            .frame(width: BoringNotchMetrics.openArtSize, height: BoringNotchMetrics.openArtSize)
            .clipShape(RoundedRectangle(cornerRadius: BoringNotchMetrics.openArtRadius, style: .continuous))
            .overlay(Color.black.opacity(isPlaying ? 0 : 0.45)
                .clipShape(RoundedRectangle(cornerRadius: BoringNotchMetrics.openArtRadius, style: .continuous)))
            .scaleEffect(isPlaying ? 1 : 0.85)
            .animation(.smooth, value: isPlaying)
        }
        .frame(width: BoringNotchMetrics.openArtSize, height: BoringNotchMetrics.openArtSize)
    }

    // MARK: Song (songInfo)

    private var songInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(music.playback?.track.title ?? " ")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(music.playback?.track.artist ?? " ")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.gray)
                .lineLimit(1)
            if NotchLyricsSupport.isEnabled(),
               BoringNotchMusicSupport.lyricsStyle(lyricsStyle) == .boringNotch,
               let playback = music.playback {
                BoringNotchLyricLine(playback: playback)
            }
        }
    }

    // MARK: Buttons (slotToolbar)

    private var slots: some View {
        HStack(spacing: 6) {
            ForEach(Array(BoringNotchMusicSlot.layout(from: storedSlots, count: slotCount).enumerated()),
                    id: \.offset) { _, slot in
                slotView(slot).frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func slotView(_ slot: BoringNotchMusicSlot) -> some View {
        switch slot {
        case .shuffle:
            hoverButton("shuffle", tint: shuffle.enabled == true ? .red : .white) { shuffle.toggle() }
                .disabled(shuffle.availability == nil && shuffle.enabled == nil)
        case .previous:
            hoverButton("backward.fill") { _ = music.send(.previous) }
        case .playPause:
            hoverButton(isPlaying ? "pause.fill" : "play.fill", large: true) { _ = music.send(.toggle) }
        case .next:
            hoverButton("forward.fill") { _ = music.send(.next) }
        case .volume:
            BoringNotchVolumeSlot()
        case .goBackward:
            hoverButton("gobackward.15") { skip(-15) }
                .disabled(music.playback?.canSeek != true)
        case .goForward:
            hoverButton("goforward.15") { skip(15) }
                .disabled(music.playback?.canSeek != true)
        case .none:
            Color.clear.frame(height: 1)
        }
    }

    private func skip(_ seconds: Double) {
        guard let playback = music.playback else { return }
        let target = BoringNotchMusicSupport.skipTarget(position: playback.position(at: Date()), by: seconds,
                                                        duration: playback.duration)
        _ = music.send(.seek(target))
    }

    /// Boring Notch's `HoverButton`: a circle that lights up under the pointer.
    private func hoverButton(_ symbol: String, tint: Color = .white, large: Bool = false,
                             action: @escaping () -> Void) -> some View {
        BoringNotchHoverButton(symbol: symbol, tint: tint, large: large, action: action)
    }
}

struct BoringNotchHoverButton: View {
    let symbol: String
    var tint: Color = .white
    var large = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: large ? 20 : 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: large ? 40 : 30, height: large ? 40 : 30)
                .background(Circle().fill(Color.white.opacity(hovering ? 0.12 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.smooth(duration: 0.2), value: hovering)
    }
}

/// Boring Notch's seek bar (MusicSliderView + CustomSlider): elapsed and
/// remaining time under a capsule track that can be dragged.
struct BoringNotchSeekBar: View {
    let playback: NotchPlayback
    let seek: (Double) -> Void
    @State private var dragValue: Double?

    var body: some View {
        TimelineView(.animation(minimumInterval: playback.isPlaying ? 0.25 : nil)) { timeline in
            let position = dragValue ?? playback.position(at: timeline.date)
            VStack(spacing: 2) {
                GeometryReader { proxy in
                    let fraction = playback.duration > 0 ? min(1, max(0, position / playback.duration)) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Color.white).frame(width: proxy.size.width * fraction)
                    }
                    .frame(height: dragValue == nil ? 5 : 8)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard playback.canSeek else { return }
                            let x = min(max(0, value.location.x), proxy.size.width)
                            dragValue = playback.duration * Double(x / max(1, proxy.size.width))
                        }
                        .onEnded { _ in
                            if let target = dragValue { seek(target) }
                            dragValue = nil
                        })
                }
                .frame(height: 10)
                HStack {
                    Text(BoringNotchMusicSupport.timeString(position))
                    Spacer()
                    Text("-" + BoringNotchMusicSupport.timeString(max(0, playback.duration - position)))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.gray)
            }
            .animation(.smooth(duration: 0.15), value: dragValue == nil)
        }
    }
}

/// Boring Notch's volume slot: the speaker, and a short slider beside it
/// while it is open. The level goes through Vorssaint's mixer.
struct BoringNotchVolumeSlot: View {
    @State private var open = false
    @State private var level = AppVolumeMixer.systemOutputVolume() ?? 0.5

    var body: some View {
        HStack(spacing: 4) {
            BoringNotchHoverButton(symbol: level <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                level = AppVolumeMixer.systemOutputVolume() ?? level
                withAnimation(.smooth) { open.toggle() }
            }
            if open {
                Slider(value: Binding(get: { level }, set: { value in
                    level = value
                    AppVolumeMixer.setSystemOutputVolume(value)
                }), in: 0...1)
                .controlSize(.mini)
                .frame(width: 48)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
    }
}

/// Boring Notch's lyrics: the current line under the artist, from
/// Vorssaint's lyrics service.
struct BoringNotchLyricLine: View {
    let playback: NotchPlayback
    @ObservedObject private var lyrics = NotchLyricsService.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: playback.isPlaying ? 0.25 : nil)) { timeline in
            Text(line(at: timeline.date))
                .font(.subheadline)
                .foregroundStyle(lyrics.state == .loading ? Color.gray.opacity(0.7) : .gray)
                .lineLimit(1)
                .opacity(playback.isPlaying ? 1 : 0)
        }
        .onAppear { lyrics.update(playback: playback, visible: true) }
        .onChange(of: playback.track.title) { _, _ in lyrics.update(playback: playback, visible: true) }
        .onDisappear { lyrics.hide() }
    }

    private func line(at date: Date) -> String {
        guard let current = lyrics.lyrics else { return lyrics.state == .loading ? "…" : " " }
        if current.instrumental { return "♪" }
        if let index = current.activeIndex(at: playback.position(at: date), offset: lyrics.offset),
           current.lines.indices.contains(index) {
            return current.lines[index].text
        }
        return current.plain.replacingOccurrences(of: "\n", with: " ")
    }
}
