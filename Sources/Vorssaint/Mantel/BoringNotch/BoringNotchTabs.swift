// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Tab row after Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// boringNotch/components/Tabs/TabSelectionView.swift.

import CoreGraphics
import Foundation

/// What the open notch shows in the Boring Notch design: its own Home and
/// Shelf, or one of Vorssaint's pages inside Boring Notch's frame (SPEC §3D:
/// "Vorssaint-only island pages appear as extra tabs, each hideable").
enum BoringNotchPage: Equatable {
    case home, shelf
    case module(NotchModule)
}

/// Which of Vorssaint's pages become tabs, which are shown, and how the row
/// fits beside the camera. The page itself follows Vorssaint's `selected`
/// section, so its shortcuts, its reopening rules and every service that
/// starts with a page keep working as they do in Vorssaint's design.
enum BoringNotchTabs {
    /// Sections Boring Notch's own Home and Shelf already cover.
    static let native: Set<NotchModule> = [.music, .controls, .calendar, .files]

    /// Vorssaint's pages that can be tabs, in the order the setting lists
    /// them. Captures stays Vorssaint's own page: its editing toolbar lives in
    /// Vorssaint's header.
    static let extras: [NotchModule] = [.timer, .notifications, .downloads, .agents, .watch, .mixer,
                                        .clipboard, .scratchpad, .camera, .system, .tools]

    /// SPEC §3D names the first eight; the camera is Boring Notch's mirror.
    /// System and Tools start hidden: they are not in Boring Notch at all.
    static let hiddenByDefault: Set<NotchModule> = [.system, .tools]

    static func hidden(_ defaults: UserDefaults = .standard) -> Set<NotchModule> {
        guard let raw = defaults.string(forKey: DefaultsKey.notchBoringHiddenTabs) else { return hiddenByDefault }
        return parse(raw)
    }

    static func parse(_ raw: String) -> Set<NotchModule> {
        Set(raw.split(separator: ",").compactMap { NotchModule(rawValue: String($0)) }.filter(extras.contains))
    }

    static func stored(_ hidden: Set<NotchModule>) -> String {
        extras.filter(hidden.contains).map(\.rawValue).joined(separator: ",")
    }

    /// The extra tabs to draw: the pages the island has, in its own order,
    /// less the hidden ones.
    static func visible(modules: [NotchModule], hidden: Set<NotchModule>) -> [NotchModule] {
        modules.filter { extras.contains($0) && !hidden.contains($0) }
    }

    /// The page for Vorssaint's selected section. Home and Shelf are
    /// remembered by the design; any other section shows its own page, so a
    /// shortcut or an activity that opens it lands there.
    static func page(selected: NotchModule, storedTab: BoringNotchTab) -> BoringNotchPage {
        if selected == .files { return .shelf }
        if native.contains(selected) { return storedTab == .shelf ? .shelf : .home }
        return .module(selected)
    }

    /// The section to select when Home or Shelf is chosen, so a Vorssaint
    /// page left behind stops (the camera, the system monitor). Nil when the
    /// island has none of them.
    static func anchor(for tab: BoringNotchTab, modules: [NotchModule]) -> NotchModule? {
        let order: [NotchModule] = tab == .shelf ? [.files, .music, .controls, .calendar] : [.music, .controls, .calendar]
        return order.first(where: modules.contains)
    }

    /// Whether Boring Notch's frame draws the open island; otherwise it is
    /// Vorssaint's (the section gallery, the app panel, a metric's detail,
    /// the captures page), still in Boring Notch's outline.
    static func drawsOpenPage(showingSections: Bool, showingAppPanel: Bool, showingMetric: Bool,
                              selected: NotchModule) -> Bool {
        !showingSections && !showingAppPanel && !showingMetric && selected != .captures
    }

    /// Boring Notch's open size, taller where a Vorssaint page needs it.
    /// Home, Shelf and the mirror keep Boring Notch's 640 × 190.
    static func openSize(selected: NotchModule, vorssaint: CGSize, mirrorIsBoringNotch: Bool) -> CGSize {
        let size = BoringNotchMetrics.openSize
        if native.contains(selected) || (selected == .camera && mirrorIsBoringNotch) { return size }
        return CGSize(width: size.width, height: max(size.height, vorssaint.height))
    }

    /// Room a page has inside the open notch: Boring Notch's insets on both
    /// sides, its header above and its padding below.
    static func pageSize(island: CGSize, headerHeight: CGFloat) -> CGSize {
        let side = BoringNotchMetrics.openRadii.top + BoringNotchMetrics.openPadding
        return CGSize(width: max(0, island.width - side * 2),
                      height: max(0, island.height - headerHeight - BoringNotchMetrics.openPadding))
    }

    /// Boring Notch's tab: 15 pt each side of the glyph.
    static let fullTabWidth: CGFloat = 46
    static let minimumTabWidth: CGFloat = 26

    /// How wide each tab is and how many sit left of the camera. Boring
    /// Notch fits its two or three tabs there; more tabs narrow first, then
    /// continue right of the camera, before the battery.
    static func layout(count: Int, left: CGFloat, right: CGFloat) -> (width: CGFloat, leftCount: Int) {
        guard count > 0 else { return (fullTabWidth, 0) }
        let left = max(0, left), right = max(0, right)
        if CGFloat(count) * fullTabWidth <= left { return (fullTabWidth, count) }
        let width = max(minimumTabWidth, min(fullTabWidth, (left + right) / CGFloat(count)))
        let leftCount = min(count, Int((left / width).rounded(.down)))
        return (width, max(leftCount, min(count, 2)))
    }
}

/// The two tabs of Boring Notch's open notch. Stored by raw value.
enum BoringNotchTab: String, CaseIterable {
    case home, shelf

    var symbol: String { self == .home ? "house.fill" : "tray.fill" }
}
