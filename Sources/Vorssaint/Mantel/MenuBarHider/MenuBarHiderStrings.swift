// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Options follow Ice by Jordan Baird (github.com/jordanbaird/Ice, GPL-3.0).

import Foundation

/// Localized strings for the menu bar hider. English and French are written;
/// every other language reads the English text until it is translated.
struct MenuBarHiderFeatureStrings {
    let title: String
    let hubDescription: String
    let enable: String
    let enableCaption: String
    let arrangeHint: String
    let showOnClick: String
    let showOnClickCaption: String
    let showOnHover: String
    let hoverDelayFormat: String
    let showOnScroll: String
    let showOnScrollCaption: String
    let autoRehide: String
    let rehideSmart: String
    let rehideTimed: String
    let rehideFocusedApp: String
    let rehideIntervalFormat: String
    let alwaysHidden: String
    let alwaysHiddenCaption: String
    let shortcuts: String
    let shortcutsCaption: String
    let toggleHidden: String
    let toggleAlwaysHidden: String
    let needsAccessibility: String
    let dividerHelp: String
    let unsupported: String

    func label(for strategy: MenuBarRehideStrategy) -> String {
        switch strategy {
        case .smart: return rehideSmart
        case .timed: return rehideTimed
        case .focusedApp: return rehideFocusedApp
        }
    }
}

extension FeatureStrings {
    static func menuBarHider(_ language: AppLanguage) -> MenuBarHiderFeatureStrings {
        switch language {
        case .fr: return .fr
        default: return .enUS
        }
    }
}

extension MenuBarHiderFeatureStrings {
    static let enUS = MenuBarHiderFeatureStrings(
        title: "Menu bar hider",
        hubDescription: "Hide menu bar icons behind a divider",
        enable: "Hide menu bar icons",
        enableCaption: "Icons left of the ‹ divider stay hidden. Click the Vorssaint icon to show them, right-click it for the panel, Control-click it for the menu.",
        arrangeHint: "To choose which icons hide, hold ⌘ and drag them to either side of the divider.",
        showOnClick: "Show on click in empty menu bar",
        showOnClickCaption: "Clicking an empty part of the menu bar shows the hidden icons. Option-click shows the always-hidden ones.",
        showOnHover: "Show on hover",
        hoverDelayFormat: "After %@ s",
        showOnScroll: "Show on scroll",
        showOnScrollCaption: "Scrolling or swiping on the menu bar shows the icons; the other way hides them.",
        autoRehide: "Hide again automatically",
        rehideSmart: "Smart",
        rehideTimed: "After a delay",
        rehideFocusedApp: "When switching apps",
        rehideIntervalFormat: "After %d s",
        alwaysHidden: "Always-hidden section",
        alwaysHiddenCaption: "A second, smaller divider. Icons left of it only show with Option-click or its shortcut.",
        shortcuts: "Keyboard shortcuts",
        shortcutsCaption: "Show and hide the icons from the keyboard.",
        toggleHidden: "Show or hide menu bar icons",
        toggleAlwaysHidden: "Show or hide always-hidden icons",
        needsAccessibility: "Show on click and on hover need Accessibility to tell the app’s menus from empty space.",
        dividerHelp: "Icons to the left of this divider are hidden. ⌘-drag icons across it to choose.",
        unsupported: "macOS 27 changed how the menu bar works, and hiding icons this way no longer works there. To remove icons you don’t want, use System Settings, Menu Bar, Allow in the Menu Bar."
    )

    static let fr = MenuBarHiderFeatureStrings(
        title: "Masquage de la barre des menus",
        hubDescription: "Masquez des icônes de la barre des menus derrière un séparateur",
        enable: "Masquer des icônes de la barre des menus",
        enableCaption: "Les icônes à gauche du séparateur ‹ restent masquées. Cliquez sur l’icône Vorssaint pour les afficher, clic droit pour le panneau, Contrôle-clic pour le menu.",
        arrangeHint: "Pour choisir les icônes masquées, maintenez ⌘ et faites-les glisser d’un côté ou de l’autre du séparateur.",
        showOnClick: "Afficher au clic dans la barre vide",
        showOnClickCaption: "Un clic sur une partie vide de la barre des menus affiche les icônes masquées. Option-clic affiche celles toujours masquées.",
        showOnHover: "Afficher au survol",
        hoverDelayFormat: "Après %@\u{00A0}s",
        showOnScroll: "Afficher au défilement",
        showOnScrollCaption: "Faire défiler ou balayer sur la barre des menus affiche les icônes, dans l’autre sens les masque.",
        autoRehide: "Masquer à nouveau automatiquement",
        rehideSmart: "Intelligent",
        rehideTimed: "Après un délai",
        rehideFocusedApp: "Au changement d’app",
        rehideIntervalFormat: "Après %d\u{00A0}s",
        alwaysHidden: "Section toujours masquée",
        alwaysHiddenCaption: "Un second séparateur, plus petit. Les icônes à sa gauche ne s’affichent qu’avec Option-clic ou son raccourci.",
        shortcuts: "Raccourcis clavier",
        shortcutsCaption: "Affichez et masquez les icônes au clavier.",
        toggleHidden: "Afficher ou masquer les icônes de la barre des menus",
        toggleAlwaysHidden: "Afficher ou masquer les icônes toujours masquées",
        needsAccessibility: "L’affichage au clic et au survol nécessite l’accessibilité pour distinguer les menus de l’app de l’espace vide.",
        dividerHelp: "Les icônes à gauche de ce séparateur sont masquées. Faites glisser des icônes avec ⌘ pour choisir.",
        unsupported: "macOS 27 a changé le fonctionnement de la barre des menus, et masquer les icônes de cette façon n’y marche plus. Pour retirer les icônes dont vous ne voulez pas, utilisez Réglages Système, Barre des menus, Autoriser dans la barre des menus."
    )
}
