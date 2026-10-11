// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Effect names and descriptions follow Mac Duo (github.com/DhananjayBhosale/MacDuo, MIT).

import Foundation

/// Localized strings for the lid animation. English and French are written;
/// every other language reads the English text until it is translated.
struct LidAnimationFeatureStrings {
    let title: String
    let hubDescription: String
    let enable: String
    let enableCaption: String
    let effectTitle: String
    let clearsAt: String
    let clearsAtCaption: String
    let clearWhenStill: String
    let clearWhenStillCaption: String
    let clearAfterFormat: String
    let perspective: String
    let softness: String
    let shadow: String
    let testDesktop: String
    let testDesktopCaption: String
    let pauseShortcut: String
    let pauseShortcutCaption: String
    let unsupported: String
    let noMetal: String
    let statusFollowing: String
    let statusStill: String
    let statusPaused: String
    let statusTesting: String
    let statusCheckingAccess: String
    let statusNeedsAccess: String
    let statusWaitingForSensor: String
    let statusWaitingForDisplay: String
    let statusCaptureFailedFormat: String
    let statusOff: String
    let effectSummaries: [FoldEffect: String]

    func summary(for effect: FoldEffect) -> String {
        effectSummaries[effect] ?? ""
    }
}

extension FeatureStrings {
    static func lidAnimation(_ language: AppLanguage) -> LidAnimationFeatureStrings {
        switch language {
        case .fr: return .fr
        default: return .enUS
        }
    }
}

extension LidAnimationFeatureStrings {
    static let enUS = LidAnimationFeatureStrings(
        title: "Lid animation",
        hubDescription: "Animate the desktop as you close the lid",
        enable: "Animate the desktop with the lid",
        enableCaption: "As you close the lid, the desktop follows it toward the hinge and fades out. Opening plays it back.",
        effectTitle: "Effect",
        clearsAt: "Starts below",
        clearsAtCaption: "The lid angle at which the effect begins. Above it, the desktop stays as it is.",
        clearWhenStill: "Clear when the lid is still",
        clearWhenStillCaption: "Holding the lid at one angle brings the desktop back. Move it to animate again.",
        clearAfterFormat: "After %d s",
        perspective: "Perspective",
        softness: "Softness",
        shadow: "Shadow",
        testDesktop: "Test on the desktop",
        testDesktopCaption: "Plays an 8 second lid sweep on your real desktop. Esc stops it.",
        pauseShortcut: "Pause the lid animation",
        pauseShortcutCaption: "Stops the effect until the lid opens again. Esc does the same while it shows.",
        unsupported: "This Mac has no lid angle sensor. It needs a MacBook Air with M2 or later, or a 14 or 16 inch MacBook Pro with M1 Pro or later.",
        noMetal: "This Mac has no supported Metal GPU.",
        statusFollowing: "Following your lid.",
        statusStill: "The lid is still. Move it to animate again.",
        statusPaused: "Paused until the lid opens again.",
        statusTesting: "Desktop test running. Esc stops it.",
        statusCheckingAccess: "Checking screen access…",
        statusNeedsAccess: "Needs Screen Recording to draw the desktop.",
        statusWaitingForSensor: "Waiting for the lid sensor. The desktop is clear.",
        statusWaitingForDisplay: "Waiting for the built-in display. It resumes on its own.",
        statusCaptureFailedFormat: "The desktop could not be captured: %@",
        statusOff: "Off.",
        effectSummaries: [
            .duo: "The desktop swells around the hinge as the lid closes.",
            .ghost: "The desktop holds its resting plane as the lid tilts and falls out of focus.",
            .roll: "The desktop curls into a roll that travels down to the hinge.",
            .shutter: "Four rigid panels slide behind each other into the hinge.",
            .flex: "One bowing flexible display collapses toward the hinge.",
            .iris: "Eight overlapping blades close an aperture above the hinge.",
        ]
    )

    static let fr = LidAnimationFeatureStrings(
        title: "Animation du capot",
        hubDescription: "Animez le bureau quand vous fermez le capot",
        enable: "Animer le bureau avec le capot",
        enableCaption: "Quand vous fermez le capot, le bureau le suit vers la charnière et s’efface. L’ouverture rejoue l’effet à l’envers.",
        effectTitle: "Effet",
        clearsAt: "Commence sous",
        clearsAtCaption: "L’angle du capot à partir duquel l’effet commence. Au-dessus, le bureau ne bouge pas.",
        clearWhenStill: "Effacer quand le capot ne bouge plus",
        clearWhenStillCaption: "Tenir le capot à un angle fixe ramène le bureau. Bougez-le pour relancer l’effet.",
        clearAfterFormat: "Après %d\u{00A0}s",
        perspective: "Perspective",
        softness: "Flou",
        shadow: "Ombre",
        testDesktop: "Tester sur le bureau",
        testDesktopCaption: "Joue un mouvement de capot de 8 secondes sur votre vrai bureau. Échap l’arrête.",
        pauseShortcut: "Mettre l’animation du capot en pause",
        pauseShortcutCaption: "Arrête l’effet jusqu’à la prochaine ouverture du capot. Échap fait de même pendant l’effet.",
        unsupported: "Ce Mac n’a pas de capteur d’angle du capot. Il faut un MacBook Air M2 ou plus récent, ou un MacBook Pro 14 ou 16 pouces M1 Pro ou plus récent.",
        noMetal: "Ce Mac n’a pas de processeur graphique Metal compatible.",
        statusFollowing: "Suit votre capot.",
        statusStill: "Le capot ne bouge plus. Bougez-le pour relancer l’effet.",
        statusPaused: "En pause jusqu’à la prochaine ouverture du capot.",
        statusTesting: "Test du bureau en cours. Échap l’arrête.",
        statusCheckingAccess: "Vérification de l’accès à l’écran…",
        statusNeedsAccess: "Nécessite l’enregistrement de l’écran pour dessiner le bureau.",
        statusWaitingForSensor: "En attente du capteur du capot. Le bureau est dégagé.",
        statusWaitingForDisplay: "En attente de l’écran intégré. Reprise automatique.",
        statusCaptureFailedFormat: "Le bureau n’a pas pu être capturé\u{00A0}: %@",
        statusOff: "Désactivé.",
        effectSummaries: [
            .duo: "Le bureau se bombe autour de la charnière quand le capot se ferme.",
            .ghost: "Le bureau garde son plan de repos pendant que le capot s’incline, puis devient flou.",
            .roll: "Le bureau s’enroule et le rouleau descend jusqu’à la charnière.",
            .shutter: "Quatre panneaux rigides glissent les uns derrière les autres dans la charnière.",
            .flex: "Un écran souple se courbe puis s’affaisse vers la charnière.",
            .iris: "Huit lames se chevauchent et ferment un diaphragme au-dessus de la charnière.",
        ]
    )
}
