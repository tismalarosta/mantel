// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// Localized strings for Type Clipboard. English and French are written;
/// every other language reads the English text until it is translated.
struct TypeClipboardFeatureStrings {
    let title: String
    let hubDescription: String
    let enable: String
    let caption: String
    let speedTitle: String
    let speedInstant: String
    let speedFast: String
    let speedNatural: String
    let speedCustom: String
    let customDelayFormat: String
    let escapeStops: String
    let escapeStopsCaption: String
    let nothingToType: String
    let secureInputBlocked: String
    let stoppedTyping: String
    let confirmTitleFormat: String
    let confirmMessageFormat: String
    let confirmType: String
    let cancel: String

    func label(for speed: TypeClipboardSpeed) -> String {
        switch speed {
        case .instant: return speedInstant
        case .fast: return speedFast
        case .natural: return speedNatural
        case .custom: return speedCustom
        }
    }
}

extension FeatureStrings {
    static func typeClipboard(_ language: AppLanguage) -> TypeClipboardFeatureStrings {
        switch language {
        case .fr: return .fr
        default: return .enUS
        }
    }
}

extension TypeClipboardFeatureStrings {
    static let enUS = TypeClipboardFeatureStrings(
        title: "Type clipboard",
        hubDescription: "Type copied text where pasting is blocked",
        enable: "Type the clipboard with a shortcut",
        caption: "Types what you copied as keystrokes, line breaks and tabs included. Works in fields that refuse pasting. The clipboard stays as it is.",
        speedTitle: "Speed",
        speedInstant: "Instant",
        speedFast: "Fast",
        speedNatural: "Natural",
        speedCustom: "Custom",
        customDelayFormat: "%d ms per character",
        escapeStops: "Press Esc to stop typing",
        escapeStopsCaption: "Pressing the shortcut again also stops it.",
        nothingToType: "No text on the clipboard",
        secureInputBlocked: "Not typed: a password field is active",
        stoppedTyping: "Stopped typing",
        confirmTitleFormat: "Type %@ characters?",
        confirmMessageFormat: "This takes about %@. Press Esc to stop at any time.",
        confirmType: "Type",
        cancel: "Cancel"
    )

    static let fr = TypeClipboardFeatureStrings(
        title: "Taper le presse-papiers",
        hubDescription: "Tapez le texte copié là où coller est bloqué",
        enable: "Taper le presse-papiers avec un raccourci",
        caption: "Tape ce que vous avez copié touche par touche, retours à la ligne et tabulations compris. Fonctionne dans les champs qui refusent le collage. Le presse-papiers ne change pas.",
        speedTitle: "Vitesse",
        speedInstant: "Instantanée",
        speedFast: "Rapide",
        speedNatural: "Naturelle",
        speedCustom: "Personnalisée",
        customDelayFormat: "%d ms par caractère",
        escapeStops: "Appuyer sur Échap pour arrêter",
        escapeStopsCaption: "Appuyer à nouveau sur le raccourci l’arrête aussi.",
        nothingToType: "Aucun texte dans le presse-papiers",
        secureInputBlocked: "Rien tapé, un champ de mot de passe est actif",
        stoppedTyping: "Frappe arrêtée",
        confirmTitleFormat: "Taper %@\u{00A0}caractères\u{00A0}?",
        confirmMessageFormat: "Cela prend environ %@. Appuyez sur Échap pour arrêter à tout moment.",
        confirmType: "Taper",
        cancel: "Annuler"
    )
}
