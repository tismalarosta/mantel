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

    static func localized(_ language: AppLanguage) -> NotchDesignStrings {
        language == .fr ? .fr : .enUS
    }

    static let enUS = NotchDesignStrings(
        title: "Design",
        caption: "Boring Notch’s shape, springs and Home and Shelf tabs, or Vorssaint’s island. Both use the same music, files and notices.",
        boringNotch: "Boring Notch",
        vorssaint: "Vorssaint")

    static let fr = NotchDesignStrings(
        title: "Design",
        caption: "La forme, les ressorts et les onglets Accueil et Étagère de Boring Notch, ou l’île de Vorssaint. Les deux utilisent la même musique, les mêmes fichiers et notifications.",
        boringNotch: "Boring Notch",
        vorssaint: "Vorssaint")
}

/// The choice at the top of the Notch page's Layout tab (SPEC §3D: "Notch
/// design: Boring Notch / Vorssaint", default Boring Notch). Switching is
/// live: the island redraws in the other design at once.
struct NotchDesignCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchDesign) private var design = NotchDesign.fallback.rawValue

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
        }
        .onChange(of: design) { _, _ in
            NotchService.shared.rebuildForDesignChange()
        }
    }
}
