// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Carbon.HIToolbox
import Foundation

/// Type Clipboard's pure rules, its shortcut defaults, and the source
/// contracts that keep it from adding a keyboard hook of its own.
enum TypeClipboardTests {
    static func run(_ suite: TestSuite) {
        decisions(suite)
        normalization(suite)
        steps(suite)
        speeds(suite)
        shortcuts(suite)
        sourceContracts(suite)
    }

    private static func decisions(_ suite: TestSuite) {
        typealias Support = TypeClipboardSupport
        suite.expect(Support.decide(text: nil, secureInput: false, confirmed: false) == .noText,
                     "an empty clipboard types nothing")
        suite.expect(Support.decide(text: " \n\t ", secureInput: false, confirmed: false) == .noText,
                     "a clipboard of blanks types nothing")
        suite.expect(Support.decide(text: "hello", secureInput: true, confirmed: true) == .secureInput,
                     "a password field never receives the clipboard, even after a confirmation")
        suite.expect(Support.decide(text: "hello", secureInput: false, confirmed: false) == .type("hello"),
                     "a short text types straight away")
        let atLimit = String(repeating: "a", count: Support.confirmationThreshold)
        suite.expect(Support.decide(text: atLimit, secureInput: false, confirmed: false) == .type(atLimit),
                     "a text of exactly the limit types without asking")
        let overLimit = atLimit + "b"
        suite.expect(Support.decide(text: overLimit, secureInput: false, confirmed: false)
                        == .needsConfirmation(overLimit),
                     "a text above the limit asks first")
        suite.expect(Support.decide(text: overLimit, secureInput: false, confirmed: true) == .type(overLimit),
                     "a confirmed long text types")
        suite.expect(Support.decide(text: "a\r\nb", secureInput: false, confirmed: false) == .type("a\nb"),
                     "the typed text is the normalized one")
    }

    private static func normalization(_ suite: TestSuite) {
        typealias Support = TypeClipboardSupport
        suite.expect(Support.normalized("a\r\nb\rc\nd") == "a\nb\nc\nd",
                     "Windows, old Mac and Unix line endings all become one newline")
        suite.expect(Support.normalized("a\r\n\r\nb") == "a\n\nb",
                     "an empty line between CRLF endings stays one empty line")
        suite.expect(Support.normalized("a\u{2028}b\u{2029}c") == "a\nb\nc",
                     "Unicode line and paragraph separators become newlines")
        suite.expect(Support.normalized("a\u{0}b\u{7}c\u{1B}d\u{7F}e") == "abcde",
                     "control characters a keyboard cannot type are dropped")
        suite.expect(Support.normalized("a\tb") == "a\tb", "tabs stay, they are typed as Tab")
        suite.expect(Support.normalized("é 👍🏽 👨‍👩‍👧") == "é 👍🏽 👨‍👩‍👧",
                     "accents and emoji pass through untouched")
    }

    private static func steps(_ suite: TestSuite) {
        typealias Support = TypeClipboardSupport
        func units(_ text: String) -> [UInt16] { Array(text.utf16) }

        suite.expect(Support.steps(for: "ab\ncd\te", grouped: true)
                        == [.text(units("ab")), .newline, .text(units("cd")), .tab, .text(units("e"))],
                     "newlines press Return and tabs press Tab, between runs of text")
        suite.expect(Support.steps(for: "\n\n", grouped: true) == [.newline, .newline],
                     "consecutive line breaks each press Return")
        suite.expect(Support.steps(for: "", grouped: true).isEmpty, "nothing to type, no steps")

        let long = Support.steps(for: String(repeating: "a", count: 45), grouped: true)
        suite.expect(long == [.text(units(String(repeating: "a", count: 20))),
                              .text(units(String(repeating: "a", count: 20))),
                              .text(units(String(repeating: "a", count: 5)))],
                     "instant typing packs text in chunks of at most 20 UTF-16 units")

        let boundary = Support.steps(for: String(repeating: "a", count: 19) + "👍", grouped: true)
        suite.expect(boundary == [.text(units(String(repeating: "a", count: 19))), .text(units("👍"))],
                     "an emoji that would cross the chunk limit moves whole to the next chunk")

        let everyStep = Support.steps(for: String(repeating: "x👍🏽é", count: 30), grouped: true)
        let within = everyStep.allSatisfy { step in
            if case .text(let chunk) = step {
                return chunk.count <= Support.maximumChunk
                    && String(decoding: chunk, as: UTF16.self).unicodeScalars.allSatisfy { $0.value != 0xFFFD }
            }
            return true
        }
        suite.expect(within, "no chunk exceeds the limit or splits a character")

        suite.expect(Support.steps(for: "hé👍", grouped: false)
                        == [.text(units("h")), .text(units("é")), .text(units("👍"))],
                     "paced typing sends one character per keystroke")
        suite.expect(Support.steps(for: "👨‍👩‍👧", grouped: false) == [.text(units("👨‍👩‍👧"))],
                     "a joined emoji family is one keystroke, never its parts")
    }

    private static func speeds(_ suite: TestSuite) {
        typealias Support = TypeClipboardSupport
        suite.expect(TypeClipboardSpeed.sanitized(nil) == .fast
                        && TypeClipboardSpeed.sanitized("warp") == .fast
                        && TypeClipboardSpeed.sanitized("natural") == .natural,
                     "an unknown or missing speed falls back to fast")
        suite.expect(TypeClipboardSpeed.allCases.map(\.rawValue) == ["instant", "fast", "natural", "custom"],
                     "speed ids are stable (they are stored)")
        suite.expect(Support.delay(for: .instant, customMilliseconds: 0, jitter: 0)
                        < Support.delay(for: .fast, customMilliseconds: 0, jitter: 0)
                        && Support.delay(for: .fast, customMilliseconds: 0, jitter: 0)
                        < Support.delay(for: .natural, customMilliseconds: 0, jitter: 0),
                     "instant is quicker than fast, which is quicker than natural")
        let slowest = Support.delay(for: .natural, customMilliseconds: 0, jitter: 1)
        let quickest = Support.delay(for: .natural, customMilliseconds: 0, jitter: 0)
        suite.expect(quickest > 0.02 && slowest < 0.07 && quickest < slowest,
                     "natural typing varies between roughly 27 and 63 ms per key")
        suite.expect(Support.delay(for: .natural, customMilliseconds: 0, jitter: 7)
                        == Support.delay(for: .natural, customMilliseconds: 0, jitter: 1),
                     "an out-of-range jitter is clamped")
        suite.expectClose(Support.delay(for: .custom, customMilliseconds: 50, jitter: 0), 0.05,
                          "a custom speed waits its chosen milliseconds")
        suite.expect(Support.sanitizedCustomDelay(0) == 1 && Support.sanitizedCustomDelay(5_000) == 200,
                     "the custom delay stays between 1 and 200 ms")
        suite.expect(Support.estimatedDuration(characters: 6_000, speed: .instant, customMilliseconds: 0) < 1,
                     "a long text typed instantly takes under a second")
        suite.expectClose(Support.estimatedDuration(characters: 100, speed: .custom, customMilliseconds: 10),
                          1, "the estimate counts one pause per character at paced speeds")
    }

    private static func shortcuts(_ suite: TestSuite) {
        let typeShortcut = GlobalShortcut.typeClipboardDefault
        suite.expect(typeShortcut.keyCode == Int64(kVK_ANSI_V)
                        && typeShortcut.modifiers == [.control, .command],
                     "Type Clipboard defaults to ⌃⌘V")
        let launcher = GlobalShortcut.quickLauncherDefault
        suite.expect(launcher.keyCode == Int64(kVK_ANSI_B)
                        && launcher.modifiers == [.control, .option, .command],
                     "the quick launcher moved to ⌃⌥⌘B so ⌃⌘V is free")
        suite.expect(GlobalShortcut(storageValue: typeShortcut.storageValue)?.storageValue
                        == typeShortcut.storageValue,
                     "the Type Clipboard shortcut survives the trip to disk")
        let defaults = Defaults.registeredDefaults
        suite.expect(defaults[DefaultsKey.typeClipboardShortcut] as? String == typeShortcut.storageValue
                        && defaults[DefaultsKey.typeClipboardEnabled] as? Bool == true
                        && defaults[DefaultsKey.typeClipboardSpeed] as? String == TypeClipboardSpeed.fallback.rawValue
                        && defaults[DefaultsKey.typeClipboardCustomDelay] as? Int
                            == TypeClipboardSupport.defaultCustomDelay
                        && defaults[DefaultsKey.typeClipboardEscapeStops] as? Bool == true,
                     "Type Clipboard ships on, at fast speed, with Esc stopping it")
        suite.expect(AppFeature.typeClipboard.installedByDefault
                        && AppFeature.typeClipboard.group == .clipboardFiles
                        && AppFeature.typeClipboard.permissions == [.accessibility]
                        && AppFeature.typeClipboard.enabledKeys == [DefaultsKey.typeClipboardEnabled],
                     "Type Clipboard is a Clipboard & files feature, installed, using Accessibility")
        let role = GlobalShortcutRole.typeClipboard
        suite.expect(role.storageKey == DefaultsKey.typeClipboardShortcut
                        && role.defaultShortcut == typeShortcut
                        && role.feature == .typeClipboard
                        && role.requiredEnableKeys == [DefaultsKey.typeClipboardEnabled],
                     "the shortcut role points at Type Clipboard's own key and switch")
    }

    private static func sourceContracts(_ suite: TestSuite) {
        let folder = "Sources/Vorssaint/Mantel/TypeClipboard/"
        func source(_ name: String) -> String {
            (try? String(contentsOfFile: folder + name, encoding: .utf8)) ?? ""
        }
        let service = source("TypeClipboardService.swift")
        suite.expect(!service.isEmpty, "the Type Clipboard service source is readable")
        suite.expect(!service.contains("tapCreate") && !service.contains("addGlobalMonitorForEvents"),
                     "Type Clipboard adds no keyboard hook: Esc is read from the key state")
        suite.expect(service.contains("source?.userData = OwnKeyEvent.textSnippetMarker"),
                     "typed keystrokes carry the marker every Vorssaint tap lets through")
        suite.expect(service.contains("IsSecureEventInputEnabled()")
                        && service.components(separatedBy: "IsSecureEventInputEnabled()").count >= 3,
                     "secure input is checked before typing and again before every keystroke")
        suite.expect(service.contains("PastePlainService.plainText(from: .general)")
                        && service.contains("GeneralPasteboardAccess.shared.async"),
                     "the clipboard is read as plain text on the shared pasteboard lane")
        suite.expect(!service.contains("setString(") && !service.contains("clearContents()"),
                     "Type Clipboard never writes to the clipboard")

        // Same typography rules Vorssaint checks in Core/*Strings.swift.
        let strings = source("TypeClipboardStrings.swift")
        let literals = strings.split(separator: "\n").filter {
            !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") && $0.contains("\"")
        }
        suite.expect(!literals.contains { $0.contains("'") },
                     "Type Clipboard text curls its apostrophes")
        let french = strings.components(separatedBy: "static let fr = ").last ?? ""
        suite.expect(![" ;", " :", " !", " ?"].contains(where: french.contains),
                     "French keeps its punctuation on the line it belongs to")
        for language in AppLanguage.allCases {
            let text = FeatureStrings.typeClipboard(language)
            suite.expect(!text.title.isEmpty && text.confirmTitleFormat.contains("%@")
                            && text.confirmMessageFormat.contains("%@")
                            && text.customDelayFormat.contains("%d"),
                         "Type Clipboard has complete strings in \(language.rawValue)")
        }
    }
}
