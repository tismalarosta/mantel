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
    let swipeTitle: String
    let swipeHub: String
    let swipeCaption: String
    let shakeTitle: String
    let shakeHub: String
    let shakeCaption: String
    let titleBarTitle: String
    let titleBarHub: String
    let titleBarCaption: String
    let switcherSwipeTitle: String
    let switcherSwipeHub: String
    let switcherSwipeCaption: String
    let switcherSwipeFingers: String
    let switcherSwipeDirection: String
    let horizontal: String
    let vertical: String
    let switcherNeeded: String
    let indicatorTitle: String
    let indicatorHub: String
    let indicatorCaption: String
    let indicatorStyle: String
    let styleLine: String
    let styleDots: String
    let dockLockTitle: String
    let dockLockHub: String
    let dockLockCaption: String
    let dockLockScreen: String
    let menuBarScreen: String
    let titleBarDesktop: String
    let titleBarDesktopCaption: String
    let appCardsTitle: String
    let appCardsHub: String
    let appCardsCaption: String
    let nothingToday: String
    let allDay: String
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
        swipeTitle: "Swipe on previews",
        swipeHub: "Swipe on a Dock preview to minimize or maximize its window",
        swipeCaption: "With two fingers on the trackpad, swipe a preview toward the Dock to minimize its window, away from it to open it filling the screen.",
        shakeTitle: "Shake to minimize the others",
        shakeHub: "Shake a dragged Dock preview to minimize the app’s other windows",
        shakeCaption: "Drag a preview out of the panel and shake it: the app’s other windows minimize and this one comes forward.",
        titleBarTitle: "Scroll on title bars",
        titleBarHub: "Scroll on a window’s title bar to maximize or centre it",
        titleBarCaption: "Scroll up on the title bar of the window in front to fill the screen, down to centre it. Scrolling down on a window maximized this way puts it back as it was.",
        switcherSwipeTitle: "Swipe to switch windows",
        switcherSwipeHub: "Swipe with three or four fingers to open the window switcher",
        switcherSwipeCaption: "Swipe with the chosen number of fingers to open the switcher, keep moving to step through it, lift to switch. If macOS uses the same swipe, change one of them in System Settings › Trackpad.",
        switcherSwipeFingers: "Fingers",
        switcherSwipeDirection: "Direction",
        horizontal: "Sideways",
        vertical: "Up and down",
        switcherNeeded: "Needs the window switcher, in Features.",
        indicatorTitle: "Mark the active app",
        indicatorHub: "A line or dots under Dock icons for the active app",
        indicatorCaption: "Draws a mark in the accent colour under the front app’s Dock icon, or a dot under every open app.",
        indicatorStyle: "Style",
        styleLine: "Line under the front app",
        styleDots: "Dots under open apps",
        dockLockTitle: "Keep the Dock on one screen",
        dockLockHub: "Stop the Dock from moving to another screen",
        dockLockCaption: "With several screens, the Dock stays on the one chosen here. Hold Option to let it move.",
        dockLockScreen: "Screen",
        menuBarScreen: "Screen with the menu bar",
        titleBarDesktop: "Sideways switches desktop",
        titleBarDesktopCaption: "Scrolling sideways on a title bar moves to the next or previous desktop.",
        appCardsTitle: "Music and calendar cards",
        appCardsHub: "Hover Music, Spotify or Calendar in the Dock for a small card",
        appCardsCaption: "Hovering a music app that is playing shows its song with play controls; hovering Calendar shows today’s events (needs the island’s calendar). Click the card to open the app.",
        nothingToday: "Nothing else today",
        allDay: "All day",
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
        swipeTitle: "Balayer les aperçus",
        swipeHub: "Balayez un aperçu du Dock pour réduire ou agrandir sa fenêtre",
        swipeCaption: "À deux doigts sur le trackpad, balayez un aperçu vers le Dock pour réduire sa fenêtre, à l’opposé pour l’ouvrir sur tout l’écran.",
        shakeTitle: "Secouer pour réduire les autres",
        shakeHub: "Secouez un aperçu du Dock glissé pour réduire les autres fenêtres de l’app",
        shakeCaption: "Sortez un aperçu du panneau et secouez-le : les autres fenêtres de l’app se réduisent et celle-ci passe devant.",
        titleBarTitle: "Défiler sur les barres de titre",
        titleBarHub: "Défilez sur la barre de titre d’une fenêtre pour l’agrandir ou la centrer",
        titleBarCaption: "Défilez vers le haut sur la barre de titre de la fenêtre au premier plan pour remplir l’écran, vers le bas pour la centrer. Vers le bas sur une fenêtre agrandie ainsi, elle reprend sa taille d’avant.",
        switcherSwipeTitle: "Balayer pour changer de fenêtre",
        switcherSwipeHub: "Balayez à trois ou quatre doigts pour ouvrir le sélecteur de fenêtres",
        switcherSwipeCaption: "Balayez avec le nombre de doigts choisi pour ouvrir le sélecteur, continuez pour avancer, levez les doigts pour changer. Si macOS utilise le même geste, changez l’un des deux dans Réglages Système › Trackpad.",
        switcherSwipeFingers: "Doigts",
        switcherSwipeDirection: "Direction",
        horizontal: "Sur le côté",
        vertical: "Haut et bas",
        switcherNeeded: "Nécessite le sélecteur de fenêtres, dans Fonctionnalités.",
        indicatorTitle: "Marquer l’app active",
        indicatorHub: "Un trait ou des points sous les icônes du Dock pour l’app active",
        indicatorCaption: "Dessine une marque de la couleur d’accent sous l’icône de l’app au premier plan, ou un point sous chaque app ouverte.",
        indicatorStyle: "Style",
        styleLine: "Trait sous l’app au premier plan",
        styleDots: "Points sous les apps ouvertes",
        dockLockTitle: "Garder le Dock sur un écran",
        dockLockHub: "Empêchez le Dock de passer sur un autre écran",
        dockLockCaption: "Avec plusieurs écrans, le Dock reste sur celui choisi ici. Maintenez Option pour le laisser passer.",
        dockLockScreen: "Écran",
        menuBarScreen: "Écran avec la barre des menus",
        titleBarDesktop: "Sur le côté change de bureau",
        titleBarDesktopCaption: "Défiler sur le côté sur une barre de titre passe au bureau suivant ou précédent.",
        appCardsTitle: "Cartes musique et calendrier",
        appCardsHub: "Survolez Musique, Spotify ou Calendrier dans le Dock pour une petite carte",
        appCardsCaption: "Survoler une app de musique en lecture montre son morceau avec les commandes ; survoler Calendrier montre les événements du jour (nécessite le calendrier de l’île). Cliquez sur la carte pour ouvrir l’app.",
        nothingToday: "Rien d’autre aujourd’hui",
        allDay: "Toute la journée",
        closeAll: "Tout fermer",
        minimizeAll: "Tout réduire",
        fullScreen: "Plein écran",
        quit: "Quitter",
        forceQuit: "Forcer à quitter"
    )
}
