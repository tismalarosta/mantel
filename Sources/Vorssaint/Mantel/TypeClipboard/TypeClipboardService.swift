// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Types the clipboard's plain text as keystrokes on a global shortcut, for
/// fields that refuse a paste. Line breaks press Return and tabs press Tab.
/// The clipboard is only read, never changed.
///
/// No keyboard tap of its own: Esc is read from the key state between two
/// keystrokes, and the typed events carry the text snippet marker so the
/// snippet tap, the debounce tap and every other Vorssaint tap let them pass.
final class TypeClipboardService: ObservableObject {
    static let shared = TypeClipboardService()

    @Published private(set) var shortcutRegistrationFailed = false
    @Published private(set) var isTyping = false

    /// Far above every Vorssaint hotkey id (quick tools use 10–80, radial
    /// wheels 1700 and up), so an upstream addition never collides.
    private let hotkey = QuickToolHotkey(id: 2600)
    private let queue = DispatchQueue(label: "mantel.type-clipboard", qos: .userInitiated)
    private let stopFlag = StopFlag()

    /// The permission prompt fires at most once per launch, same as
    /// Paste as plain text.
    private var promptedForAccessibility = false

    private init() {
        hotkey.onPress = { [weak self] in self?.handleShortcut() }
    }

    func syncWithPreferences() {
        let enabled = AppFeature.typeClipboard.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.typeClipboardEnabled)
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.typeClipboardShortcut,
                                            fallback: .typeClipboardDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut,
                                                  storageKey: DefaultsKey.typeClipboardShortcut)
        if !enabled { stop() }
    }

    func suspend() {
        hotkey.unregister()
        stop()
    }

    func stop() {
        stopFlag.set(true)
    }

    /// The shortcut starts typing, and pressed again while typing, stops it.
    private func handleShortcut() {
        if isTyping {
            stop()
            return
        }
        guard AXIsProcessTrusted() else {
            if promptedForAccessibility {
                NSSound.beep()
            } else {
                promptedForAccessibility = true
                Permissions.shared.requestAccessibility()
            }
            return
        }
        // Promised content renders when read, so the read runs on the shared
        // pasteboard lane and answers back on main.
        GeneralPasteboardAccess.shared.async({ PastePlainService.plainText(from: .general) }) { [weak self] text in
            self?.begin(with: text, confirmed: false)
        }
    }

    private func begin(with text: String?, confirmed: Bool) {
        let strings = FeatureStrings.typeClipboard(L10n.shared.language)
        switch TypeClipboardSupport.decide(text: text,
                                           secureInput: IsSecureEventInputEnabled(),
                                           confirmed: confirmed) {
        case .noText:
            QuickToolHUD.show(icon: "doc.on.clipboard", message: strings.nothingToType)
        case .secureInput:
            QuickToolHUD.show(icon: "lock.fill", message: strings.secureInputBlocked)
        case .needsConfirmation(let typed):
            confirm(typed, strings: strings)
        case .type(let typed):
            type(typed)
        }
    }

    /// Asks before a long text. The alert takes focus, so the app that was
    /// in front gets it back before the first keystroke goes out.
    private func confirm(_ text: String, strings: TypeClipboardFeatureStrings) {
        let target = NSWorkspace.shared.frontmostApplication
        let settings = Self.currentSettings()
        let count = NumberFormatter.localizedString(from: NSNumber(value: text.count), number: .decimal)
        let seconds = TypeClipboardSupport.estimatedDuration(characters: text.count,
                                                             speed: settings.speed,
                                                             customMilliseconds: settings.customDelay)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 60 ? [.hour, .minute] : [.second]
        formatter.unitsStyle = .full
        let duration = formatter.string(from: max(seconds, 1)) ?? ""

        let alert = NSAlert()
        alert.messageText = String(format: strings.confirmTitleFormat, count)
        alert.informativeText = String(format: strings.confirmMessageFormat, duration)
        alert.addButton(withTitle: strings.confirmType)
        alert.addButton(withTitle: strings.cancel)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if let target, target != NSRunningApplication.current {
            ActivationHandoff.yield(to: target)
            if !target.activate(from: NSRunningApplication.current, options: []) {
                target.activate(options: [])
            }
        }
        // Give the field its focus back before typing into it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.type(text)
        }
    }

    private struct Settings {
        let speed: TypeClipboardSpeed
        let customDelay: Int
        let escapeStops: Bool
    }

    private static func currentSettings() -> Settings {
        let defaults = UserDefaults.standard
        return Settings(
            speed: TypeClipboardSpeed.sanitized(defaults.string(forKey: DefaultsKey.typeClipboardSpeed)),
            customDelay: defaults.integer(forKey: DefaultsKey.typeClipboardCustomDelay),
            escapeStops: defaults.bool(forKey: DefaultsKey.typeClipboardEscapeStops)
        )
    }

    private func type(_ text: String) {
        guard !isTyping else { return }
        let settings = Self.currentSettings()
        let steps = TypeClipboardSupport.steps(for: text, grouped: settings.speed == .instant)
        isTyping = true
        stopFlag.set(false)
        let stopFlag = self.stopFlag

        queue.async { [weak self] in
            let outcome = Self.post(steps, settings: settings, stopFlag: stopFlag)
            DispatchQueue.main.async {
                self?.isTyping = false
                let strings = FeatureStrings.typeClipboard(L10n.shared.language)
                switch outcome {
                case .finished:
                    break
                case .stopped:
                    QuickToolHUD.show(icon: "stop.circle", message: strings.stoppedTyping)
                case .secureInput:
                    QuickToolHUD.show(icon: "lock.fill", message: strings.secureInputBlocked)
                }
            }
        }
    }

    private enum Outcome { case finished, stopped, secureInput }

    /// Runs on the typing queue. Waits for the shortcut's own modifiers to
    /// come up first: a held ⌃⌘ would turn every typed letter into a
    /// command. Then posts each step, checking for Esc, a second press of
    /// the shortcut and a password field before every one.
    private static func post(_ steps: [TypeClipboardStep],
                             settings: Settings,
                             stopFlag: StopFlag) -> Outcome {
        let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift, .maskControl]
        let modifierDeadline = Date().addingTimeInterval(1.5)
        while !CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty,
              Date() < modifierDeadline {
            if stopFlag.value { return .stopped }
            usleep(15_000)
        }
        usleep(60_000)

        let source = CGEventSource(stateID: .hidSystemState)
        source?.userData = OwnKeyEvent.textSnippetMarker
        let escape = CGKeyCode(kVK_Escape)

        func press(_ keyCode: Int) {
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: down)
                event?.flags = []
                event?.post(tap: .cghidEventTap)
            }
        }

        for step in steps {
            // A modifier held mid-way (the shortcut pressed again to stop,
            // or the user reaching for ⌘) pauses typing, so no letter ever
            // goes out as a command.
            while !CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty {
                if stopFlag.value { return .stopped }
                usleep(10_000)
            }
            if stopFlag.value { return .stopped }
            if settings.escapeStops, CGEventSource.keyState(.combinedSessionState, key: escape) {
                return .stopped
            }
            // A password field that takes focus mid-way gets nothing more.
            if IsSecureEventInputEnabled() { return .secureInput }

            switch step {
            case .newline:
                press(kVK_Return)
            case .tab:
                press(kVK_Tab)
            case .text(let units):
                for down in [true, false] {
                    guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else {
                        continue
                    }
                    event.flags = []
                    event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
                    event.post(tap: .cghidEventTap)
                }
            }
            let pause = TypeClipboardSupport.delay(for: settings.speed,
                                                   customMilliseconds: settings.customDelay,
                                                   jitter: Double.random(in: 0...1))
            usleep(useconds_t(pause * 1_000_000))
        }
        return .finished
    }
}

/// A stop request shared between the main thread and the typing queue.
private final class StopFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false

    var value: Bool { lock.withLock { stored } }

    func set(_ newValue: Bool) { lock.withLock { stored = newValue } }
}
