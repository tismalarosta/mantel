// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Slots and defaults from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0),
// boringNotch/models/MusicControlButton.swift.

import Foundation

/// One button slot of Boring Notch's player. Boring Notch also has repeat
/// and favorite; Vorssaint's music service has neither, so they are left
/// out rather than drawn as buttons that do nothing. Stored by raw value.
enum BoringNotchMusicSlot: String, CaseIterable {
    case shuffle, previous, playPause, next, volume, goBackward, goForward, none

    static let defaultLayout: [BoringNotchMusicSlot] = [.none, .previous, .playPause, .next, .none]
    static let minSlotCount = 3
    static let maxSlotCount = 5
    static let pickerOptions: [BoringNotchMusicSlot] = [.shuffle, .previous, .playPause, .next, .volume,
                                                        .goBackward, .goForward, .none]

    var symbol: String {
        switch self {
        case .shuffle: return "shuffle"
        case .previous: return "backward.fill"
        case .playPause: return "playpause.fill"
        case .next: return "forward.fill"
        case .volume: return "speaker.wave.2.fill"
        case .goBackward: return "gobackward.15"
        case .goForward: return "goforward.15"
        case .none: return "circle.dashed"
        }
    }

    /// The stored layout ("none,previous,…"), unknown names dropped, cut
    /// or padded with empty slots to `count` (Boring Notch's `padded`).
    static func layout(from stored: String?, count: Int) -> [BoringNotchMusicSlot] {
        let count = min(max(count, minSlotCount), maxSlotCount)
        let decoded = (stored ?? "").split(separator: ",").compactMap { BoringNotchMusicSlot(rawValue: String($0)) }
        let base = decoded.isEmpty ? defaultLayout : decoded
        let padded = base + Array(repeating: .none, count: max(0, count - base.count))
        return Array(padded.prefix(count))
    }

    static func stored(_ layout: [BoringNotchMusicSlot]) -> String {
        layout.map(\.rawValue).joined(separator: ",")
    }
}

/// SPEC §3D's pick-one settings for the music surfaces.
enum BoringNotchVisualizer: String, CaseIterable {
    /// Boring Notch's four animated bars.
    case boringNotch
    /// Vorssaint's live equalizer, read from the player's audio.
    case vorssaint
}

enum BoringNotchLyricsStyle: String, CaseIterable {
    /// Boring Notch: the current line under the artist.
    case boringNotch
    /// Vorssaint: the scrolling lyrics panel, beside the player.
    case vorssaint
}

/// What Home's right column shows. Stored by raw value.
enum BoringNotchSidePanel: String, CaseIterable {
    case calendar, upNext, lyrics

    var symbol: String {
        switch self {
        case .calendar: return "calendar"
        case .upNext: return "list.bullet"
        case .lyrics: return "quote.bubble"
        }
    }
}

enum BoringNotchMusicSupport {
    static func visualizer(_ raw: String?) -> BoringNotchVisualizer {
        raw.flatMap(BoringNotchVisualizer.init(rawValue:)) ?? .boringNotch
    }

    static func lyricsStyle(_ raw: String?) -> BoringNotchLyricsStyle {
        raw.flatMap(BoringNotchLyricsStyle.init(rawValue:)) ?? .boringNotch
    }

    /// Boring Notch's slider labels: m:ss, or h:mm:ss past an hour.
    static func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        let paddedSeconds = secs < 10 ? "0\(secs)" : "\(secs)"
        if hours > 0 {
            let paddedMinutes = minutes < 10 ? "0\(minutes)" : "\(minutes)"
            return "\(hours):\(paddedMinutes):\(paddedSeconds)"
        }
        return "\(minutes):\(paddedSeconds)"
    }

    /// Where a ±15 s skip lands, inside the track.
    static func skipTarget(position: Double, by offset: Double, duration: Double) -> Double {
        guard position.isFinite, duration.isFinite, duration > 0 else { return 0 }
        return min(duration, max(0, position + offset))
    }
}
