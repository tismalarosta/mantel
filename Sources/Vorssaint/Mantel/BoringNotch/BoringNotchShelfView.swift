// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// components/Shelf/Views/ShelfView.swift, ShelfItemView.swift, FileShareView.swift.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Localized strings for Boring Notch's shelf. English and French are
/// written; other languages read English.
struct BoringNotchShelfStrings {
    let share, dropHere, empty, open, openWith, other, showInFinder, copyPath: String
    let removeBackground, convert, makePDF, compress, remove, failed: String

    static func localized(_ language: AppLanguage) -> BoringNotchShelfStrings { language == .fr ? .fr : .enUS }

    static let enUS = BoringNotchShelfStrings(
        share: "Share", dropHere: "Drop files here", empty: "Drop files on the notch to keep them here",
        open: "Open", openWith: "Open With", other: "Other…", showInFinder: "Show in Finder", copyPath: "Copy Path",
        removeBackground: "Remove Background", convert: "Convert Image…", makePDF: "Create PDF",
        compress: "Compress", remove: "Remove", failed: "That did not work on this file.")

    static let fr = BoringNotchShelfStrings(
        share: "Partager", dropHere: "Déposez des fichiers ici", empty: "Déposez des fichiers sur l’encoche pour les garder ici",
        open: "Ouvrir", openWith: "Ouvrir avec", other: "Autre…", showInFinder: "Afficher dans le Finder",
        copyPath: "Copier le chemin", removeBackground: "Supprimer l’arrière-plan", convert: "Convertir l’image…",
        makePDF: "Créer un PDF", compress: "Compresser", remove: "Retirer", failed: "Cela n’a pas fonctionné sur ce fichier.")
}

/// Boring Notch's Shelf tab on Vorssaint's shelf: the Quick Share tile, then
/// the items in a row. While Vorssaint's media tool is open (Convert), the
/// tab shows Vorssaint's files page, which hosts it.
struct BoringNotchShelfView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var shelf = ShelfService.shared
    @ObservedObject private var tools = NotchFileToolsService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var shareAnchor = ShelfSharePickerAnchor.Anchor()
    @State private var shareTargeted = false
    @State private var failure: String?

    private var text: BoringNotchShelfStrings { BoringNotchShelfStrings.localized(l10n.language) }

    var body: some View {
        if tools.mediaPresented {
            ScrollView(.vertical, showsIndicators: false) { NotchFilesView(service: service) }
        } else {
            HStack(spacing: 10) {
                shareTile
                items
            }
            .padding(.top, 6)
            .overlay(alignment: .bottom) {
                if let failure {
                    Text(failure).font(.caption).foregroundStyle(.orange)
                        .task { try? await Task.sleep(for: .seconds(3)); self.failure = nil }
                }
            }
        }
    }

    // MARK: Quick Share (FileShareView)

    private var shareTile: some View {
        Button { pickAndShare() } label: {
            VStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 22, weight: .medium))
                Text(text.share).font(.caption).fontWeight(.medium)
            }
            .foregroundStyle(shareTargeted ? Color.white : Color.gray)
            .frame(width: 96, height: 104)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(shareTargeted ? 0.6 : 0.18),
                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(ShelfSharePickerAnchor(anchor: shareAnchor))
        .onDrop(of: [.fileURL], isTargeted: $shareTargeted) { providers in
            Self.loadURLs(providers) { urls in
                guard !urls.isEmpty else { return }
                shareAnchor.present(urls)
            }
            return true
        }
    }

    private func pickAndShare() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        service.open()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shareAnchor.present(panel.urls) }
    }

    // MARK: Items (ShelfView + ShelfItemView)

    @ViewBuilder private var items: some View {
        if shelf.items.isEmpty {
            Text(text.empty)
                .font(.subheadline).foregroundStyle(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.04)))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(shelf.items) { item in tile(item) }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func fileURL(_ item: ShelfService.Item) -> URL? {
        if case let .file(url) = item.payload { return url }
        return nil
    }

    private func tile(_ item: ShelfService.Item) -> some View {
        VStack(spacing: 4) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: item.hasContentThumbnail ? .fill : .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(item.title)
                .font(.caption2).foregroundStyle(.white).lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 76)
        }
        .padding(4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { open(item) }
        .onDrag { Self.provider(for: item) }
        .contextMenu { menu(for: item) }
    }

    @ViewBuilder private func menu(for item: ShelfService.Item) -> some View {
        let urls = fileURL(item).map { [$0] } ?? []
        let actions = BoringNotchShelfSupport.actions(fileURLs: urls, hasOtherItems: urls.isEmpty,
                                                      mediaToolsAvailable: AppFeature.mediaTools.isAvailable)
        ForEach(actions, id: \.self) { action in
            switch action {
            case .openWith:
                if let url = urls.first {
                    Menu(text.openWith) {
                        ForEach(NSWorkspace.shared.urlsForApplications(toOpen: url).prefix(12), id: \.self) { app in
                            Button(FileManager.default.displayName(atPath: app.path)) {
                                NSWorkspace.shared.open([url], withApplicationAt: app, configuration: .init())
                            }
                        }
                    }
                }
            default:
                Button(title(action), role: action == .remove ? .destructive : nil) { perform(action, item, urls) }
            }
        }
    }

    private func title(_ action: BoringNotchShelfAction) -> String {
        switch action {
        case .open: return text.open
        case .openWith: return text.openWith
        case .showInFinder: return text.showInFinder
        case .share: return text.share
        case .copyPath: return text.copyPath
        case .removeBackground: return text.removeBackground
        case .convert: return text.convert
        case .makePDF: return text.makePDF
        case .compress: return text.compress
        case .remove: return text.remove
        }
    }

    private func perform(_ action: BoringNotchShelfAction, _ item: ShelfService.Item, _ urls: [URL]) {
        switch action {
        case .open: open(item)
        case .openWith: break
        case .showInFinder: NSWorkspace.shared.activateFileViewerSelecting(urls)
        case .share: shareAnchor.present(urls)
        case .copyPath:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
        case .removeBackground:
            guard let url = urls.first else { return }
            runInBackground { try BoringNotchImageActions.removeBackground(from: url) }
        case .convert:
            // Vorssaint's image tool: convert and compress live there (SPEC: Vorssaint wins).
            _ = NotchFileToolsService.shared.openMedia(.imageCompressor, inputs: urls)
        case .makePDF:
            runInBackground { try BoringNotchImageActions.makePDF(from: urls) }
        case .compress:
            guard let directory = try? BoringNotchImageActions.outputDirectory() else { return }
            if urls.count == 1, let url = urls.first {
                let destination = directory.appendingPathComponent(
                    BoringNotchShelfSupport.outputName(for: url, suffix: nil, extension: "zip"))
                NotchFileToolsService.shared.archive(urls, destination: destination, directory: false)
            } else {
                NotchFileToolsService.shared.archive(urls, destination: directory, directory: true)
            }
        case .remove: shelf.removeItem(item.id)
        }
    }

    private func open(_ item: ShelfService.Item) {
        switch item.payload {
        case let .file(url), let .link(url): NSWorkspace.shared.open(url)
        case let .text(string):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        case .batch: break
        }
    }

    private func runInBackground(_ work: @escaping () throws -> URL) {
        let message = text.failed
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try work() }
            DispatchQueue.main.async {
                switch result {
                case let .success(url): _ = ShelfService.shared.addFiles([url])
                case .failure: failure = message
                }
            }
        }
    }

    /// Dragging an item out hands the file itself (or its text or link).
    private static func provider(for item: ShelfService.Item) -> NSItemProvider {
        switch item.payload {
        case let .file(url): return NSItemProvider(contentsOf: url) ?? NSItemProvider()
        case let .link(url): return NSItemProvider(object: url as NSURL)
        case let .text(string): return NSItemProvider(object: string as NSString)
        case let .batch(items): return items.first.map(provider(for:)) ?? NSItemProvider()
        }
    }

    private static func loadURLs(_ providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        var urls: [URL] = []
        let group = DispatchGroup()
        let lock = NSLock()
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL { lock.withLock { urls.append(url) } }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(urls) }
    }
}
