// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Shape, sizes and springs from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// boringNotch/components/Notch/NotchShape.swift (originally Kai Azim's DynamicNotchKit,
// github.com/MrKai77/DynamicNotchKit), boringNotch/sizing/matters.swift, boringNotch/ContentView.swift.

import CoreGraphics
import Foundation

/// Which design the island draws (SPEC §3D). Boring Notch is a view layer
/// on Vorssaint's island: same window, services, notices and settings; only
/// the silhouette, its springs and the open page change. Stored by raw value.
enum NotchDesign: String, CaseIterable {
    case boringNotch, vorssaint

    static let fallback: NotchDesign = .boringNotch

    static func sanitized(_ raw: String?) -> NotchDesign {
        raw.flatMap(NotchDesign.init(rawValue:)) ?? fallback
    }

    static func current(_ defaults: UserDefaults = .standard) -> NotchDesign {
        sanitized(defaults.string(forKey: DefaultsKey.notchDesign))
    }

    /// The hooks in Vorssaint's island ask this, and it is cheap: two reads.
    /// An island that is not installed has no design to apply.
    static var isBoringNotch: Bool {
        AppFeature.notch.isAvailable && current() == .boringNotch
    }
}

/// Boring Notch's numbers, kept in one place.
enum BoringNotchMetrics {
    /// `openNotchSize` in sizing/matters.swift.
    static let openSize = CGSize(width: 640, height: 190)
    /// `cornerRadiusInsets`: closed (top 6, bottom 14), open (top 19, bottom 24).
    static let closedRadii = (top: CGFloat(6), bottom: CGFloat(14))
    static let openRadii = (top: CGFloat(19), bottom: CGFloat(24))
    /// Heights the radii blend between, so a growing island changes its
    /// corners as smoothly as its size (Boring Notch animates them too).
    static let closedHeight: CGFloat = 32
    static let openHeight: CGFloat = 150
    /// Album art closed and open (`MusicPlayerImageSizes`).
    static let closedArtRadius: CGFloat = 4
    static let openArtSize: CGFloat = 90
    static let openArtRadius: CGFloat = 13
    /// The open page's inner padding (ContentView: 12 pt, plus the corner).
    static let openPadding: CGFloat = 12

    /// Corner radii for an island of `height`.
    static func radii(height: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        let span = openHeight - closedHeight
        let t = span > 0 ? min(1, max(0, (height - closedHeight) / span)) : 1
        return (closedRadii.top + (openRadii.top - closedRadii.top) * t,
                closedRadii.bottom + (openRadii.bottom - closedRadii.bottom) * t)
    }

    /// The open spring (response 0.42, damping 0.8) and the closing one
    /// (response 0.45, damping 1.0), as duration and bounce = 1 − damping.
    static let openSpring = (duration: 0.42, bounce: 0.2)
    static let closeSpring = (duration: 0.45, bounce: 0.0)

    /// Boring Notch's outline (DynamicNotchKit's): flared top corners curving
    /// out into the menu bar, straight sides, rounded bottom corners. Points
    /// in a top-left-origin rect, as SwiftUI and Vorssaint's mask draw it.
    static func outline(in rect: CGRect, top: CGFloat, bottom: CGFloat) -> CGPath {
        let top = min(max(0, top), rect.width / 4, rect.height / 2)
        let bottom = min(max(0, bottom), (rect.width - top * 2) / 2, rect.height - top)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top),
                          control: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
                          control: CGPoint(x: rect.minX + top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
                          control: CGPoint(x: rect.maxX - top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
