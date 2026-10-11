// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// components/Shelf/Services/ImageProcessingService.swift (removeBackground, createPDF).

import AppKit
import CoreImage
import PDFKit
import UniformTypeIdentifiers
import Vision

/// The two image actions of Boring Notch's shelf that Vorssaint lacks.
/// Convert and compress go to Vorssaint's own image tool, zip to its archive
/// tool. Everything runs on this Mac; results land next to a temporary copy
/// and are added back to the shelf.
enum BoringNotchImageActions {
    enum Failure: Error { case unreadable, noSubject, writeFailed }

    /// Where results go before the shelf takes them.
    static func outputDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mantel Shelf", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Vision's foreground mask (macOS 14), as Boring Notch does: the subject
    /// kept, the rest transparent, saved as PNG.
    static func removeBackground(from url: URL) throws -> URL {
        guard let image = CIImage(contentsOf: url) else { throw Failure.unreadable }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: image)
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw Failure.noSubject
        }
        let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances,
                                                         from: handler, croppedToInstancesExtent: false)
        let masked = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(masked, from: masked.extent) else { throw Failure.writeFailed }
        let output = try outputDirectory().appendingPathComponent(
            BoringNotchShelfSupport.outputName(for: url, suffix: "no background", extension: "png"))
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { throw Failure.writeFailed }
        try data.write(to: output, options: .atomic)
        return output
    }

    /// One PDF page per image, in shelf order (Boring Notch's "Create PDF").
    static func makePDF(from urls: [URL]) throws -> URL {
        let document = PDFDocument()
        for url in urls {
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else { continue }
            document.insert(page, at: document.pageCount)
        }
        guard document.pageCount > 0, let first = urls.first else { throw Failure.unreadable }
        let output = try outputDirectory().appendingPathComponent(
            BoringNotchShelfSupport.outputName(for: first, suffix: urls.count > 1 ? "images" : nil, extension: "pdf"))
        guard document.write(to: output) else { throw Failure.writeFailed }
        return output
    }
}
