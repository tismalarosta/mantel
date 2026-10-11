// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// How fast Type Clipboard types. Stored by raw value, so cases can be added
/// but never renamed.
enum TypeClipboardSpeed: String, CaseIterable {
    case instant, fast, natural, custom

    static let fallback: TypeClipboardSpeed = .fast

    static func sanitized(_ raw: String?) -> TypeClipboardSpeed {
        raw.flatMap(TypeClipboardSpeed.init(rawValue:)) ?? fallback
    }
}

/// One thing to post: a run of text in a single keystroke event, or a key
/// that has to be pressed for real because a unicode string cannot carry it
/// (a line break typed as text never becomes Return in a web form).
enum TypeClipboardStep: Equatable {
    case text([UInt16])
    case newline
    case tab
}

/// The pure half of Type Clipboard: what to type, in which steps, how fast.
/// Nothing here touches the clipboard, the keyboard or the screen.
enum TypeClipboardSupport {
    /// Longer texts ask first: typing a whole document by accident takes
    /// minutes and cannot be undone in one step.
    static let confirmationThreshold = 5_000
    /// Milliseconds per character for the custom speed.
    static let customDelayRange = 1...200
    static let defaultCustomDelay = 20
    /// Keystroke events carry at most ~20 UTF-16 units reliably
    /// (`TextSnippetService.postExpansion` types in the same chunks).
    static let maximumChunk = 20

    enum Decision: Equatable {
        case type(String)
        case noText
        case secureInput
        case needsConfirmation(String)
    }

    /// What a press of the shortcut should do with what is on the clipboard.
    /// Secure input wins over everything: a password field must never receive
    /// typed clipboard text, and the system would drop it anyway.
    static func decide(text: String?, secureInput: Bool, confirmed: Bool) -> Decision {
        guard !secureInput else { return .secureInput }
        let typed = normalized(text ?? "")
        guard typed.contains(where: { !$0.isWhitespace }) else { return .noText }
        if !confirmed, typed.count > confirmationThreshold {
            return .needsConfirmation(typed)
        }
        return .type(typed)
    }

    /// Line endings become a single newline and the control characters a
    /// keyboard cannot produce are dropped; tabs and newlines stay, since
    /// they are typed as their keys.
    static func normalized(_ text: String) -> String {
        var result = ""
        result.unicodeScalars.reserveCapacity(text.unicodeScalars.count)
        var previousWasCarriageReturn = false
        for scalar in text.unicodeScalars {
            defer { previousWasCarriageReturn = scalar == "\r" }
            switch scalar {
            case "\r", "\u{2028}", "\u{2029}", "\u{85}":
                result.unicodeScalars.append("\n")
            case "\n":
                if !previousWasCarriageReturn { result.unicodeScalars.append("\n") }
            case "\t":
                result.unicodeScalars.append(scalar)
            default:
                let isControl = scalar.value < 0x20 || (0x7F...0x9F).contains(scalar.value)
                if !isControl { result.unicodeScalars.append(scalar) }
            }
        }
        return result
    }

    /// The text cut into posting steps. Grouped (instant speed) packs whole
    /// characters into chunks of at most `maximumChunk` UTF-16 units; paced
    /// speeds send one character per step so each keystroke can wait its
    /// turn. A character is never split, so an emoji or an accented letter
    /// never arrives as two broken halves.
    static func steps(for text: String, grouped: Bool) -> [TypeClipboardStep] {
        var steps: [TypeClipboardStep] = []
        var pending: [UInt16] = []
        func flush() {
            guard !pending.isEmpty else { return }
            steps.append(.text(pending))
            pending.removeAll(keepingCapacity: true)
        }
        for character in text {
            if character == "\n" || character == "\r\n" {
                flush()
                steps.append(.newline)
                continue
            }
            if character == "\t" {
                flush()
                steps.append(.tab)
                continue
            }
            let units = Array(String(character).utf16)
            if !grouped || pending.count + units.count > maximumChunk {
                flush()
            }
            pending.append(contentsOf: units)
            if !grouped { flush() }
        }
        flush()
        return steps
    }

    static func sanitizedCustomDelay(_ milliseconds: Int) -> Int {
        min(max(milliseconds, customDelayRange.lowerBound), customDelayRange.upperBound)
    }

    /// Pause after each step, in seconds. `jitter` is a 0...1 random draw;
    /// only the natural speed uses it, to type at an uneven human rhythm.
    /// Instant still breathes a millisecond between chunks so a busy app's
    /// event queue never overflows on a long text.
    static func delay(for speed: TypeClipboardSpeed, customMilliseconds: Int, jitter: Double) -> TimeInterval {
        switch speed {
        case .instant: return 0.001
        case .fast: return 0.008
        case .natural:
            let spread = min(max(jitter, 0), 1)
            return 0.045 * (0.6 + 0.8 * spread)
        case .custom:
            return Double(sanitizedCustomDelay(customMilliseconds)) / 1_000
        }
    }

    /// Rough time a text takes, shown before a long text is typed.
    static func estimatedDuration(characters: Int,
                                  speed: TypeClipboardSpeed,
                                  customMilliseconds: Int) -> TimeInterval {
        let perStep = delay(for: speed, customMilliseconds: customMilliseconds, jitter: 0.5)
        let steps = speed == .instant ? (characters + maximumChunk - 1) / maximumChunk : characters
        return Double(steps) * perStep
    }
}
