// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// Views/Hover Window/Special Hover Windows/Folder (FolderWidgetModel, FolderWidgetView).

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// C10: resting the pointer on a Dock folder (Downloads, Documents, any
/// stack) opens a small grid of its files, newest first. Click opens a file,
/// dragging takes it out, the header opens the folder in Finder. Vorssaint's
/// Dock preview reports pointer moves over the Dock that hit no app; this
/// looks for a folder there, at most ten times a second.
final class DockFolderPop {
    static let shared = DockFolderPop()

    static let restDelay: TimeInterval = 0.35
    static let maximumItems = 48

    private var panel: NSPanel?
    private var shown: DockIcons.Folder?
    private var pending: DockIcons.Folder?
    private var lastLook: CFAbsoluteTime = 0
    private var watcher: Timer?
    private var outsideTicks = 0

    private init() {}

    /// From Vorssaint's Dock preview, in top-left coordinates, only while
    /// the pointer is in the Dock's strip and over no app.
    func pointerMoved(at point: CGPoint) {
        guard DockExtrasSupport.folderPopOn else { return }
        if let shown, Self.contains(shown.frame, point) { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastLook > 0.1 else { return }
        lastLook = now
        guard let folder = DockIcons.folder(at: point) else {
            pending = nil
            return
        }
        guard pending != folder else { return }
        pending = folder
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restDelay) { [weak self] in
            guard let self, self.pending == folder, DockExtrasSupport.folderPopOn,
                  Self.contains(folder.frame, Self.topLeftMouse()) else { return }
            self.pending = nil
            self.show(folder)
        }
    }

    func hide() {
        watcher?.invalidate()
        watcher = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        shown = nil
    }

    private func show(_ folder: DockIcons.Folder) {
        let items = DockExtrasSupport.folderItems(in: folder.url, limit: Self.maximumItems)
        let orientation = DockPreviewOrientation.sanitized(
            UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation"))
        let panel = ensurePanel()
        let hosting = NSHostingView(rootView: FolderPopView(folder: folder.url, items: items) { [weak self] in
            self?.hide()
        })
        panel.contentView = hosting
        let icon = Self.appKitRect(folder.frame)
        panel.setFrame(Self.frame(size: hosting.fittingSize, icon: icon, orientation: orientation), display: true)
        panel.orderFrontRegardless()
        shown = folder
        watch(icon: icon)
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle]
        self.panel = panel
        return panel
    }

    private func watch(icon: CGRect) {
        watcher?.invalidate()
        outsideTicks = 0
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            // A file being dragged out keeps the grid until it is dropped.
            guard NSEvent.pressedMouseButtons == 0 else { return }
            if panel.frame.union(icon).insetBy(dx: -12, dy: -12).contains(NSEvent.mouseLocation) {
                self.outsideTicks = 0
            } else {
                self.outsideTicks += 1
                if self.outsideTicks >= 2 { self.hide() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        watcher = timer
    }

    private static func contains(_ frame: CGRect, _ point: CGPoint) -> Bool {
        frame.insetBy(dx: -2, dy: -40).contains(point) || frame.insetBy(dx: -40, dy: -2).contains(point)
    }

    private static func topLeftMouse() -> CGPoint {
        let mouse = NSEvent.mouseLocation
        let primary = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: mouse.x, y: primary - mouse.y)
    }

    private static func appKitRect(_ rect: CGRect) -> CGRect {
        let primary = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primary - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func frame(size: CGSize, icon: CGRect, orientation: DockPreviewOrientation) -> CGRect {
        var origin: CGPoint
        switch orientation {
        case .bottom: origin = CGPoint(x: icon.midX - size.width / 2, y: icon.maxY + 10)
        case .left: origin = CGPoint(x: icon.maxX + 10, y: icon.midY - size.height / 2)
        case .right: origin = CGPoint(x: icon.minX - 10 - size.width, y: icon.midY - size.height / 2)
        }
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(icon) })?.visibleFrame {
            origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - size.width - 8)
            origin.y = min(max(origin.y, screen.minY + 8), screen.maxY - size.height - 8)
        }
        return CGRect(origin: origin, size: size)
    }
}

private struct FolderPopView: View {
    let folder: URL
    let items: [DockExtrasSupport.FolderItem]
    let close: () -> Void

    @ObservedObject private var l10n = L10n.shared
    private var text: DockExtrasFeatureStrings { FeatureStrings.dockExtras(l10n.language) }
    private let columns = Array(repeating: GridItem(.fixed(76), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(FileManager.default.displayName(atPath: folder.path))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    NSWorkspace.shared.open(folder)
                    close()
                } label: {
                    Label(text.openInFinder, systemImage: "folder")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            if items.isEmpty {
                Text(text.folderEmpty).font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(width: 5 * 76 + 4 * 6, alignment: .leading)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(items, id: \.url) { item in tile(item) }
                    }
                }
                .frame(width: 5 * 76 + 4 * 6, height: min(CGFloat((items.count + 4) / 5), 3) * 92)
            }
        }
        .padding(12)
        .background(HUDBackdrop(cornerRadius: 16, opacity: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private func tile(_ item: DockExtrasSupport.FolderItem) -> some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 48, height: 48)
            Text(item.url.lastPathComponent)
                .font(.system(size: 10)).lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 72, height: 28, alignment: .top)
        }
        .frame(width: 76, height: 84)
        .contentShape(Rectangle())
        .onTapGesture {
            NSWorkspace.shared.open(item.url)
            close()
        }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .help(item.url.lastPathComponent)
    }
}
