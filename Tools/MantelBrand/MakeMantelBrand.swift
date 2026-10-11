// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
//
// Draws Mantel's own brand masters (Vorssaint's TRADEMARKS.md: a fork needs
// its own icon and logo): AppIcon-Default.png (1024 px app icon) and logo.png
// (the black mark the menu bar glyph and BrandMark are cut from), in the
// layout Tools/MakeIcon.swift reads. Usage: swift MakeMantelBrand.swift <style> <outDir>
import AppKit

let style = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "night"
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ".")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func canvas(_ px: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)!
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
}

func symbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        .applying(.init(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
}

func drawCentered(_ image: NSImage, in rect: CGRect, scale: CGFloat) {
    let size = image.size
    let factor = min(rect.width * scale / size.width, rect.height * scale / size.height)
    let target = CGSize(width: size.width * factor, height: size.height * factor)
    image.draw(in: CGRect(x: rect.midX - target.width / 2, y: rect.midY - target.height / 2,
                          width: target.width, height: target.height))
}

/// A drawn flame: three nested tongues (outer, middle, core), each a
/// teardrop leaning a little, the way a fire flickers.
func flamePath(in r: CGRect, lean: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    let base = CGPoint(x: r.midX, y: r.minY)
    let tip = CGPoint(x: r.midX + r.width * lean, y: r.maxY)
    p.move(to: base)
    p.curve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.38),
            controlPoint1: CGPoint(x: r.midX - r.width * 0.42, y: r.minY),
            controlPoint2: CGPoint(x: r.minX, y: r.minY + r.height * 0.16))
    p.curve(to: tip,
            controlPoint1: CGPoint(x: r.minX, y: r.minY + r.height * 0.66),
            controlPoint2: CGPoint(x: r.midX - r.width * 0.05, y: r.minY + r.height * 0.78))
    p.curve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.38),
            controlPoint1: CGPoint(x: r.midX + r.width * 0.30, y: r.minY + r.height * 0.70),
            controlPoint2: CGPoint(x: r.maxX, y: r.minY + r.height * 0.62))
    p.curve(to: base,
            controlPoint1: CGPoint(x: r.maxX, y: r.minY + r.height * 0.16),
            controlPoint2: CGPoint(x: r.midX + r.width * 0.42, y: r.minY))
    p.close()
    return p
}

func drawFire(in r: CGRect, colors: [NSColor]) {
    // Two crossed logs, then the tongues from the outside in.
    let log = NSColor(red: 0.42, green: 0.24, blue: 0.14, alpha: 1)
    log.setFill()
    for angle in [-9.0, 9.0] {
        let t = NSAffineTransform()
        t.translateX(by: r.midX, yBy: r.minY + r.height * 0.07)
        t.rotate(byDegrees: CGFloat(angle))
        let bar = NSBezierPath(roundedRect: CGRect(x: -r.width * 0.46, y: -r.height * 0.045,
                                                   width: r.width * 0.92, height: r.height * 0.09),
                               xRadius: r.height * 0.045, yRadius: r.height * 0.045)
        bar.transform(using: t as AffineTransform)
        bar.fill()
    }
    let layers: [(CGFloat, CGFloat, CGFloat)] = [(1.0, 1.0, 0.06), (0.70, 0.74, -0.08), (0.40, 0.46, 0.05)]
    for (i, layer) in layers.enumerated() {
        let w = r.width * 0.80 * layer.0, h = r.height * 0.88 * layer.1
        colors[i].setFill()
        flamePath(in: CGRect(x: r.midX - w / 2, y: r.minY + r.height * 0.08, width: w, height: h), lean: layer.2).fill()
    }
}

/// The mark: a mantel shelf over a fireplace, a fire in its opening.
func drawMark(in rect: CGRect, color: NSColor, hearth: NSColor?, fire: [NSColor]?) {
    let w = rect.width, h = rect.height
    color.setFill()
    // Shelf: a wide slab with a slight overhang.
    NSBezierPath(roundedRect: CGRect(x: rect.minX + w * 0.04, y: rect.minY + h * 0.78, width: w * 0.92, height: h * 0.11),
                 xRadius: w * 0.03, yRadius: w * 0.03).fill()
    // Fireplace with a tall arched opening.
    let body = NSBezierPath(roundedRect: CGRect(x: rect.minX + w * 0.12, y: rect.minY + h * 0.06, width: w * 0.76, height: h * 0.68),
                            xRadius: w * 0.04, yRadius: w * 0.04)
    let ox = rect.minX + w * 0.25, ow = w * 0.50, oy = rect.minY + h * 0.06, oh = h * 0.56
    let opening = NSBezierPath()
    opening.move(to: CGPoint(x: ox, y: oy))
    opening.line(to: CGPoint(x: ox, y: oy + oh - ow / 2))
    opening.appendArc(withCenter: CGPoint(x: ox + ow / 2, y: oy + oh - ow / 2), radius: ow / 2, startAngle: 180, endAngle: 0, clockwise: true)
    opening.line(to: CGPoint(x: ox + ow, y: oy))
    opening.close()
    body.append(opening)
    body.windingRule = .evenOdd
    body.fill()
    if let hearth {
        hearth.setFill()
        opening.fill()
    }
    if let fire {
        NSGraphicsContext.saveGraphicsState()
        opening.addClip()
        drawFire(in: CGRect(x: ox + ow * 0.12, y: oy + oh * 0.02, width: ow * 0.76, height: oh * 0.80), colors: fire)
        NSGraphicsContext.restoreGraphicsState()
    }
}

struct Palette { let top: NSColor; let bottom: NSColor; let mark: NSColor; let flame: NSColor }
let palettes: [String: Palette] = [
    "ember": Palette(top: NSColor(red: 0.98, green: 0.55, blue: 0.20, alpha: 1), bottom: NSColor(red: 0.80, green: 0.18, blue: 0.12, alpha: 1),
                     mark: NSColor(red: 1, green: 0.97, blue: 0.92, alpha: 1), flame: NSColor(red: 0.95, green: 0.35, blue: 0.10, alpha: 1)),
    "night": Palette(top: NSColor(red: 0.16, green: 0.20, blue: 0.32, alpha: 1), bottom: NSColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1),
                     mark: NSColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1), flame: NSColor(red: 1.0, green: 0.62, blue: 0.20, alpha: 1)),
    "stone": Palette(top: NSColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1), bottom: NSColor(red: 0.82, green: 0.80, blue: 0.76, alpha: 1),
                     mark: NSColor(red: 0.20, green: 0.19, blue: 0.18, alpha: 1), flame: NSColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1)),
]
guard let palette = palettes[style] else { print("styles: ember, night, stone"); exit(1) }

// App icon: macOS squircle with a soft vertical gradient.
let icon = canvas(1024)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: icon)
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(starting: palette.top, ending: palette.bottom)!.draw(in: squircle, angle: -90)
let fire = [NSColor(red: 0.93, green: 0.27, blue: 0.10, alpha: 1), NSColor(red: 1.0, green: 0.56, blue: 0.13, alpha: 1),
            NSColor(red: 1.0, green: 0.86, blue: 0.38, alpha: 1)]
// The arch stays open on the tile's own colour: only the fire and its logs inside.
drawMark(in: tile.insetBy(dx: 130, dy: 130), color: palette.mark, hearth: nil, fire: fire)
NSGraphicsContext.restoreGraphicsState()
save(icon, "AppIcon-Default.png")

// Logo: the mark alone in black, the flame cut out so the menu bar glyph reads as one shape.
let logo = canvas(512)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: logo)
drawMark(in: CGRect(x: 0, y: 0, width: 512, height: 512), color: .black, hearth: nil, fire: nil)
// A small solid flame in the opening, so the glyph reads as a fire at 16 pt.
NSColor.black.setFill()
flamePath(in: CGRect(x: 512 * 0.38, y: 512 * 0.08, width: 512 * 0.24, height: 512 * 0.30), lean: 0.05).fill()
NSGraphicsContext.restoreGraphicsState()
save(logo, "logo.png")
print("ok \(style)")
