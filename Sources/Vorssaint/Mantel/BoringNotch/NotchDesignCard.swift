// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import SwiftUI

/// Localized strings for the notch design choice. English and French are
/// written; every other language reads the English text until translated.
struct NotchDesignStrings {
    let title: String
    let caption: String
    let boringNotch: String
    let vorssaint: String
    let buttons: String
    let buttonsCaption: String
    let visualizer: String
    let visualizerLive: String
    let lyrics: String
    let lyricsLine: String
    let lyricsPanel: String
    let slotNames: [BoringNotchMusicSlot: String]

    static func localized(_ language: AppLanguage) -> NotchDesignStrings {
        language == .fr ? .fr : .enUS
    }

    static let enUS = NotchDesignStrings(
        title: "Design",
        caption: "Boring Notch’s shape, springs and Home and Shelf tabs, or Vorssaint’s island. Both use the same music, files and notices.",
        boringNotch: "Boring Notch",
        vorssaint: "Vorssaint",
        buttons: "Player buttons",
        buttonsCaption: "Choose what each slot does, from three to five slots.",
        visualizer: "Music bars",
        visualizerLive: "Live equalizer",
        lyrics: "Lyrics",
        lyricsLine: "One line",
        lyricsPanel: "Panel",
        slotNames: [.shuffle: "Shuffle", .previous: "Previous", .playPause: "Play / Pause", .next: "Next",
                    .volume: "Volume", .goBackward: "Back 15 s", .goForward: "Forward 15 s", .none: "Empty"])

    static let fr = NotchDesignStrings(
        title: "Design",
        caption: "La forme, les ressorts et les onglets Accueil et Étagère de Boring Notch, ou l’île de Vorssaint. Les deux utilisent la même musique, les mêmes fichiers et notifications.",
        boringNotch: "Boring Notch",
        vorssaint: "Vorssaint",
        buttons: "Boutons du lecteur",
        buttonsCaption: "Choisissez le rôle de chaque emplacement, de trois à cinq.",
        visualizer: "Barres de musique",
        visualizerLive: "Égaliseur en direct",
        lyrics: "Paroles",
        lyricsLine: "Une ligne",
        lyricsPanel: "Panneau",
        slotNames: [.shuffle: "Aléatoire", .previous: "Précédent", .playPause: "Lecture / Pause", .next: "Suivant",
                    .volume: "Volume", .goBackward: "Recul 15\u{00A0}s", .goForward: "Avance 15\u{00A0}s", .none: "Vide"])
}

/// The choice at the top of the Notch page's Layout tab (SPEC §3D: "Notch
/// design: Boring Notch / Vorssaint", default Boring Notch). Switching is
/// live: the island redraws in the other design at once.
struct NotchDesignCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchDesign) private var design = NotchDesign.fallback.rawValue
    @AppStorage(DefaultsKey.notchBoringMusicSlots) private var storedSlots = BoringNotchMusicSlot.stored(BoringNotchMusicSlot.defaultLayout)
    @AppStorage(DefaultsKey.notchBoringMusicSlotCount) private var slotCount = 5
    @AppStorage(DefaultsKey.notchBoringVisualizer) private var visualizer = BoringNotchVisualizer.boringNotch.rawValue
    @AppStorage(DefaultsKey.notchBoringLyricsStyle) private var lyricsStyle = BoringNotchLyricsStyle.boringNotch.rawValue

    private var text: NotchDesignStrings { NotchDesignStrings.localized(l10n.language) }

    var body: some View {
        SettingsCard(title: text.title) {
            Picker(text.title, selection: $design) {
                Text(text.boringNotch).tag(NotchDesign.boringNotch.rawValue)
                Text(text.vorssaint).tag(NotchDesign.vorssaint.rawValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(text.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if NotchDesign.sanitized(design) == .boringNotch {
                musicOptions
            }
        }
        .onChange(of: design) { _, _ in
            NotchService.shared.rebuildForDesignChange()
        }
    }

    /// Boring Notch's music options (its slot editor, simplified to one
    /// picker per slot) and SPEC §3D's pick-one choices.
    @ViewBuilder private var musicOptions: some View {
        let layout = BoringNotchMusicSlot.layout(from: storedSlots, count: slotCount)
        SettingsRow(symbol: "playpause", title: text.buttons, caption: text.buttonsCaption) {
            Stepper(value: Binding(get: { layout.count }, set: { count in
                slotCount = count
                storedSlots = BoringNotchMusicSlot.stored(BoringNotchMusicSlot.layout(from: storedSlots, count: count))
            }), in: BoringNotchMusicSlot.minSlotCount...BoringNotchMusicSlot.maxSlotCount) {
                Text("\(layout.count)").monospacedDigit()
            }
        }
        HStack(spacing: 6) {
            ForEach(Array(layout.enumerated()), id: \.offset) { index, slot in
                Menu {
                    ForEach(BoringNotchMusicSlot.pickerOptions, id: \.self) { option in
                        Button {
                            var next = layout
                            next[index] = option
                            storedSlots = BoringNotchMusicSlot.stored(next)
                        } label: {
                            Label(text.slotNames[option] ?? option.rawValue, systemImage: option.symbol)
                        }
                    }
                } label: {
                    Image(systemName: slot.symbol)
                        .frame(width: 34, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(text.slotNames[slot] ?? slot.rawValue)
            }
        }
        .padding(.leading, settingsRowTextInset)
        if AppFeature.notchLiveEqualizer.isAvailable {
            SettingsRow(symbol: "waveform", title: text.visualizer) {
                Picker(text.visualizer, selection: $visualizer) {
                    Text(text.boringNotch).tag(BoringNotchVisualizer.boringNotch.rawValue)
                    Text(text.visualizerLive).tag(BoringNotchVisualizer.vorssaint.rawValue)
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        if AppFeature.notchLyrics.isAvailable {
            SettingsRow(symbol: "quote.bubble", title: text.lyrics) {
                Picker(text.lyrics, selection: $lyricsStyle) {
                    Text(text.lyricsLine).tag(BoringNotchLyricsStyle.boringNotch.rawValue)
                    Text(text.lyricsPanel).tag(BoringNotchLyricsStyle.vorssaint.rawValue)
                }
                .labelsHidden()
                .fixedSize()
            }
        }
    }
}
