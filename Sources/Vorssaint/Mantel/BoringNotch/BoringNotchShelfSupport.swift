// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Menu from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// components/Shelf/Views/ShelfItemView.swift (context menu, image actions).

import Foundation
import UniformTypeIdentifiers

/// One entry of Boring Notch's shelf item menu.
enum BoringNotchShelfAction: String, CaseIterable {
    case open, openWith, showInFinder, share, copyPath, removeBackground, convert, makePDF, compress, remove
}

/// The pure half of Boring Notch's shelf tab.
enum BoringNotchShelfSupport {
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif",
                                               "bmp", "webp"]

    static func isImage(_ url: URL) -> Bool {
        if imageExtensions.contains(url.pathExtension.lowercased()) { return true }
        return UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
    }

    /// "Photo no background.png": the source's name, a suffix, a new extension.
    static func outputName(for url: URL, suffix: String?, extension ext: String) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        let name = [base.isEmpty ? "Untitled" : base, suffix].compactMap { $0 }.joined(separator: " ")
        return name + "." + ext
    }

    /// The menu for the items it acts on (Boring Notch's shelf menu, image
    /// actions only for images, compress for files; Vorssaint's image tool
    /// and archive tool behind convert and compress, so they show only when
    /// those are installed).
    static func actions(fileURLs: [URL], hasOtherItems: Bool, mediaToolsAvailable: Bool)
        -> [BoringNotchShelfAction] {
        let files = !fileURLs.isEmpty
        let allImages = files && fileURLs.allSatisfy(isImage)
        let single = fileURLs.count == 1 && !hasOtherItems
        var list: [BoringNotchShelfAction] = []
        if files { list.append(.open) }
        if single { list += [.openWith, .showInFinder] }
        if files { list += [.share, .copyPath] }
        if allImages, single { list.append(.removeBackground) }
        if allImages, single, mediaToolsAvailable { list.append(.convert) }
        if allImages { list.append(.makePDF) }
        if files, mediaToolsAvailable { list.append(.compress) }
        list.append(.remove)
        return list
    }
}
