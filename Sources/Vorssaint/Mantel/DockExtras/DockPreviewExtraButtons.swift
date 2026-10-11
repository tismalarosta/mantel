// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0):
// Views/Hover Window/Shared Components/Traffic Light Buttons.swift (window buttons)
// and WindowPreviewHoverContainer.swift (Close All / Minimize All).

import AppKit
import SwiftUI

/// C2: the window buttons DockDoor has and Vorssaint's cards lack. Vorssaint
/// already draws close and minimize (it wins the overlap), so this adds full
/// screen and quit, with ⌥ turning quit into force quit. Drawn in the same
/// circle style beside them, and only while the card shows its controls.
struct DockPreviewExtraWindowButtons: View {
    let window: SwitcherItem
    let visible: Bool
    /// The card's own guard, so a button press never also opens the window.
    let willAct: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @State private var hovering: String?
    @State private var optionHeld = false

    var body: some View {
        if DockExtrasSupport.windowButtonsOn {
            HStack(spacing: 4) {
                if let windowID = window.windowID, !window.isMinimized {
                    circleButton(id: "fullscreen",
                                 symbol: window.isFullscreen ? "arrow.down.right.and.arrow.up.left.circle.fill"
                                                             : "arrow.up.left.and.arrow.down.right.circle.fill",
                                 tint: Color(red: 0.16, green: 0.78, blue: 0.25),
                                 help: text.fullScreen) {
                        WindowActivator.toggleFullScreen(windowID: windowID, pid: window.windowOwnerPID)
                    }
                }
                circleButton(id: "quit", symbol: optionHeld ? "bolt.circle.fill" : "power.circle.fill",
                             tint: Color(red: 1.0, green: 0.62, blue: 0.2),
                             help: optionHeld ? text.forceQuit : text.quit) {
                    guard let app = NSRunningApplication(processIdentifier: window.pid), !app.isTerminated,
                          DockExtrasSupport.canQuit(bundleID: app.bundleIdentifier,
                                                    isOwnApp: app.processIdentifier
                                                        == ProcessInfo.processInfo.processIdentifier)
                    else { return }
                    if NSEvent.modifierFlags.contains(.option) { app.forceTerminate() } else { app.terminate() }
                }
            }
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
                guard visible else { return }
                let held = NSEvent.modifierFlags.contains(.option)
                if held != optionHeld { optionHeld = held }
            }
        }
    }

    private var text: DockExtrasFeatureStrings { FeatureStrings.dockExtras(l10n.language) }

    private func circleButton(id: String, symbol: String, tint: Color, help: String,
                              action: @escaping () -> Void) -> some View {
        Button {
            willAct()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white.opacity(hovering == id ? 0.95 : 0.72),
                                 tint.opacity(hovering == id ? 1 : 0.88))
                .frame(width: 16, height: 16)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 ? id : (hovering == id ? nil : hovering) }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// C5: Close All and Minimize All for the app whose windows the preview
/// shows, in the panel's header (DockDoor's mass actions).
struct DockPreviewMassActionButtons: View {
    let windows: [SwitcherItem]

    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if DockExtrasSupport.massActionsOn, !windows.isEmpty {
            HStack(spacing: 6) {
                headerButton(symbol: "minus.rectangle", title: text.minimizeAll) {
                    for item in windows where !item.isMinimized && !item.isFullscreen {
                        guard let id = item.windowID else { continue }
                        WindowActivator.setWindowMinimized(true, windowID: id, pid: item.windowOwnerPID)
                    }
                }
                headerButton(symbol: "xmark.rectangle", title: text.closeAll) {
                    for item in windows {
                        guard let id = item.windowID else { continue }
                        _ = WindowActivator.closeWindow(windowID: id, appPID: item.pid,
                                                        windowOwnerPID: item.windowOwnerPID)
                    }
                }
            }
        }
    }

    private var text: DockExtrasFeatureStrings { FeatureStrings.dockExtras(l10n.language) }

    private func headerButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 10.5, weight: .semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(title)
    }
}
