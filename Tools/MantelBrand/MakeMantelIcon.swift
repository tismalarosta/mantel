// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
//
// Builds Mantel's app icon master from its mark (Resources/MantelBrand/mark.png,
// a floating shelf over an arch with an orb, made with ChatGPT from Matisse's
// brief): a graphite macOS tile with the mark in white and a soft shadow,
// Vorssaint's look inverted so the fork is not mistaken for it (Vorssaint's
// TRADEMARKS.md). Tools/MakeIcon.swift then cuts every size and the menu bar
// glyph (from logo.png, the same mark) through BRAND_DIR.
// Usage: swift MakeMantelIcon.swift Resources/MantelBrand/mark.png Resources/MantelBrand/AppIcon-Default.png
import AppKit

let mark = NSImage(contentsOfFile: CommandLine.arguments[1])!
let out = CommandLine.arguments[2]
let top = NSColor(srgbRed: 0.20, green: 0.21, blue: 0.24, alpha: 1)  // graphite
let bottom = top.blended(withFraction: 0.55, of: .black)!

func whiteMark() -> NSImage {
    NSImage(size: mark.size, flipped: false) { r in
        mark.draw(in: r); NSColor(white: 0.97, alpha: 1).set(); r.fill(using: .sourceAtop); return true }
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(starting: top, ending: bottom)!.draw(in: shape, angle: -90)
// A faint rim, like light catching the tile's edge.
NSColor(white: 1, alpha: 0.08).setStroke(); shape.lineWidth = 4; shape.stroke()
shape.addClip()
let shadow = NSShadow(); shadow.shadowColor = NSColor(white: 0, alpha: 0.55)
shadow.shadowOffset = NSSize(width: 0, height: -14); shadow.shadowBlurRadius = 26; shadow.set()
whiteMark().draw(in: tile.insetBy(dx: 60, dy: 60))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
