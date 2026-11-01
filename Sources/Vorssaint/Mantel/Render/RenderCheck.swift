// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Same approach as Regis's `--render` (~/GitHub/regis, HQ/RenderCheck.swift).

import AppKit
import SwiftUI

/// `Mantel --render <dir>`: the settings window, the menu bar panel and the open
/// notch drawn offscreen to PNGs, with this Mac's real settings and data. A
/// visual check that needs no Screen Recording permission. Blur and translucency
/// (materials, Liquid Glass) do not survive an offscreen draw, so the real look
/// still needs the app on screen. From Claude's sandbox, run it through
/// `open -n -W -a /Applications/Mantel.app --args --render <dir>`: a direct run
/// cannot reach CoreBrightness there and the settings sidebar crashes on it.
@MainActor
enum RenderCheck {
    static func runIfRequestedAndExit() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--render"), args.indices.contains(i + 1) else { return }
        let dir = args[i + 1]
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        _ = NSApplication.shared
        var written: [String] = []
        // The real window paints its own background behind the page; offscreen there is none, so the page's text would sit on white
        let settings = SettingsView().background(Color(nsColor: .windowBackgroundColor))
        if save(settings, CGSize(width: 980, height: 720), dir + "/settings.png") { written.append("settings.png") }
        if save(MenuPanelView(), nil, dir + "/menu.png") { written.append("menu.png") }
        let notch = NotchService.shared
        let size = notch.expandedSize
        let island = BoringNotchOpenView(service: notch)
            .frame(width: size.width, height: size.height)
            .background(NotchShape(attached: true, radius: NotchLayout.surfaceRadius(height: size.height)).fill(.black))
            .environment(\.colorScheme, .dark)
        if save(island, size, dir + "/notch.png") { written.append("notch.png") }
        print("rendered to \(dir): \(written.joined(separator: ", "))")
        exit(written.count == 3 ? 0 : 1)
    }

    /// Hosts the view in a borderless offscreen window and writes it as PNG.
    /// A nil size lets the view pick its own (the menu panel sizes itself).
    private static func save<V: View>(_ view: V, _ size: CGSize?, _ path: String) -> Bool {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size ?? host.fittingSize)
        let win = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))   // let onAppear and async state land
        host.layoutSubtreeIfNeeded()
        guard host.bounds.width > 0, host.bounds.height > 0,
              let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }
}
