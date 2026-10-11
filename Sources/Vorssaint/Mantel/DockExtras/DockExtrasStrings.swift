// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Features follow DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0).

import Foundation

/// Localized strings for Mantel's DockDoor extras. English and French are
/// written; every other language reads the English text until translated.
struct DockExtrasFeatureStrings {
    let cardTitle: String
    let quitClickTitle: String
    let quitClickHub: String
    let quitClickCaption: String
    let scrollTitle: String
    let scrollHub: String
    let scrollCaption: String
    let scrollMediaVolume: String
    let scrollMediaVolumeCaption: String
    let massActionsTitle: String
    let massActionsHub: String
    let massActionsCaption: String
    let windowButtonsTitle: String
    let windowButtonsHub: String
    let windowButtonsCaption: String
    let closeAll: String
    let minimizeAll: String
    let fullScreen: String
    let quit: String
    let forceQuit: String
}

extension FeatureStrings {
    static func dockExtras(_ language: AppLanguage) -> DockExtrasFeatureStrings {
        switch language {
        case .fr: return .fr
        default: return .enUS
        }
    }
}

extension DockExtrasFeatureStrings {
    static let enUS = DockExtrasFeatureStrings(
        cardTitle: "Dock extras",
        quitClickTitle: "Quit from the Dock",
        quitClickHub: "⌘ right-click a Dock icon to quit the app",
        quitClickCaption: "Command right-click a Dock icon to quit its app. Add Option to force quit. Finder is never quit.",
        scrollTitle: "Scroll on Dock icons",
        scrollHub: "Scroll on a Dock icon to show or hide its app",
        scrollCaption: "Scroll up on an app’s Dock icon to bring it forward, down to hide it.",
        scrollMediaVolume: "Volume on Spotify and Music",
        scrollMediaVolumeCaption: "Scrolling on their icons turns the Mac’s volume instead.",
        massActionsTitle: "Close All and Minimize All",
        massActionsHub: "Close or minimize all of an app’s windows from its preview",
        massActionsCaption: "Adds both buttons to the top of the Dock preview.",
        windowButtonsTitle: "More window buttons",
        windowButtonsHub: "Full screen and quit buttons on Dock previews",
        windowButtonsCaption: "Adds full screen and quit beside close and minimize on each preview. Hold Option to force quit.",
        closeAll: "Close All",
        minimizeAll: "Minimize All",
        fullScreen: "Full screen",
        quit: "Quit",
        forceQuit: "Force quit"
    )

    static let fr = DockExtrasFeatureStrings(
        cardTitle: "Extras du Dock",
        quitClickTitle: "Quitter depuis le Dock",
        quitClickHub: "⌘ clic droit sur une icône du Dock pour quitter l’app",
        quitClickCaption: "Commande clic droit sur une icône du Dock quitte son app. Ajoutez Option pour forcer. Le Finder n’est jamais quitté.",
        scrollTitle: "Défiler sur les icônes du Dock",
        scrollHub: "Défilez sur une icône du Dock pour afficher ou masquer l’app",
        scrollCaption: "Défiler vers le haut sur l’icône d’une app la met au premier plan, vers le bas la masque.",
        scrollMediaVolume: "Volume sur Spotify et Musique",
        scrollMediaVolumeCaption: "Défiler sur leurs icônes règle plutôt le volume du Mac.",
        massActionsTitle: "Tout fermer et Tout réduire",
        massActionsHub: "Fermez ou réduisez toutes les fenêtres d’une app depuis son aperçu",
        massActionsCaption: "Ajoute les deux boutons en haut de l’aperçu du Dock.",
        windowButtonsTitle: "Plus de boutons de fenêtre",
        windowButtonsHub: "Boutons plein écran et quitter sur les aperçus du Dock",
        windowButtonsCaption: "Ajoute plein écran et quitter à côté de fermer et réduire sur chaque aperçu. Maintenez Option pour forcer.",
        closeAll: "Tout fermer",
        minimizeAll: "Tout réduire",
        fullScreen: "Plein écran",
        quit: "Quitter",
        forceQuit: "Forcer à quitter"
    )
}
