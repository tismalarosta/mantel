// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// After Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0): boringNotchApp.swift
// (showOnLockScreen keeps the closed notch over the lock screen), ContentView.swift (MusicLiveActivity).

import SwiftUI

/// The notch over the lock screen, in the design chosen (SPEC §3D pick-one).
/// Vorssaint's lock screen service still decides when it shows and where;
/// in Boring Notch's look it is the closed notch with its outline, the cover
/// beside the camera and its bars. With no song, Vorssaint's padlock stays,
/// so locking and unlocking still read.
struct BoringNotchLockScreenChoice: View {
    let boring: Bool
    @ObservedObject var model: NotchLockScreenModel
    let vorssaint: NotchLockScreenIsland
    @ObservedObject private var music = NotchMusicService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if boring { boringNotch } else { vorssaint }
    }

    private var boringNotch: some View {
        let size = vorssaint.size
        let wing = max(0, (size.width - vorssaint.cameraWidth) / 2)
        let side = max(0, min(wing, size.height - 12))
        let radii = BoringNotchMetrics.radii(height: size.height)
        let showsMusic = model.showsMusic(music.playback)
        let playing = showsMusic && music.playback?.isPlaying == true
        return Path(BoringNotchMetrics.outline(in: CGRect(origin: .zero, size: size), top: radii.top, bottom: radii.bottom))
            .fill(.black)
            .overlay {
                HStack(spacing: 0) {
                    Group {
                        if showsMusic, let artwork = music.artwork {
                            Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
                                .frame(width: side, height: side)
                                .clipShape(RoundedRectangle(cornerRadius: BoringNotchMetrics.closedArtRadius, style: .continuous))
                        } else {
                            Image(systemName: model.padlockOpen ? "lock.open.fill" : "lock.fill")
                                .font(.system(size: min(13, size.height * 0.42), weight: .semibold))
                                .foregroundStyle(.white)
                                .contentTransition(.symbolEffect(.replace))
                                .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: model.padlockOpen)
                        }
                    }
                    .frame(width: wing, height: size.height)
                    Color.clear.frame(width: vorssaint.cameraWidth)
                    BoringNotchBars(isPlaying: playing)
                        .frame(width: 16, height: 12)
                        .opacity(showsMusic ? 1 : 0)
                        .frame(width: wing, height: size.height)
                }
            }
            .frame(width: size.width, height: size.height)
            .padding(.leading, vorssaint.origin.x)
            .padding(.top, vorssaint.origin.y)
            .frame(width: vorssaint.window?.width ?? size.width, height: vorssaint.window?.height ?? size.height,
                   alignment: .topLeading)
            .environment(\.colorScheme, .dark)
            .accessibilityHidden(true)
    }
}
