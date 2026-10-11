// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// Views/Hover Window/Special Hover Windows/Media and Calendar.

import AppKit
import SwiftUI

/// C13: hovering the Music or Spotify icon while it plays shows a small
/// player card; hovering Calendar shows today's events. The card takes the
/// place of the window preview for those apps (DockDoor's special controls).
/// It reads Vorssaint's own music and calendar services and adds no source:
/// with nothing playing, or the island's calendar off, the usual preview
/// opens instead.
final class DockAppCard {
    static let shared = DockAppCard()

    fileprivate enum Content { case music(pid_t), calendar }

    private var panel: NSPanel?
    private var iconFrame: CGRect = .zero
    private var shownPID: pid_t?
    private var watcher: Timer?
    private var outsideTicks = 0

    static let calendarBundleID = "com.apple.iCal"

    private init() {}

    /// Called when the Dock preview is about to open for an app. True when
    /// the card took over; any other app closes a card left up.
    func show(for app: NSRunningApplication, iconFrame: CGRect, orientation: DockPreviewOrientation) -> Bool {
        guard DockExtrasSupport.appCardsOn, let content = content(for: app) else {
            hide()
            return false
        }
        if shownPID == app.processIdentifier, panel?.isVisible == true { return true }
        self.iconFrame = iconFrame
        shownPID = app.processIdentifier
        let panel = ensurePanel()
        let view = DockAppCardView(content: content, app: app) { [weak self] in self?.hide() }
        let hosting = NSHostingView(rootView: view)
        panel.contentView = hosting
        let size = hosting.fittingSize
        panel.setFrame(Self.frame(size: size, icon: iconFrame, orientation: orientation), display: true)
        panel.orderFrontRegardless()
        watch()
        return true
    }

    func hide() {
        watcher?.invalidate()
        watcher = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        shownPID = nil
    }

    private func content(for app: NSRunningApplication) -> Content? {
        let bundleID = app.bundleIdentifier
        if bundleID.map(DockExtrasSupport.mediaBundleIDs.contains) == true,
           NotchMusicService.shared.playback?.track.appPID == app.processIdentifier {
            return .music(app.processIdentifier)
        }
        if bundleID == Self.calendarBundleID, NotchCalendarSupport.isEnabled() { return .calendar }
        return nil
    }

    /// Above the icon for a bottom Dock, beside it for a side Dock, kept on
    /// the icon's screen.
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

    /// The card closes once the pointer has left both it and its icon (and
    /// the gap between them) for a moment; only polled while it is up.
    private func watch() {
        watcher?.invalidate()
        outsideTicks = 0
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self, let panel = self.panel else { return }
            let zone = panel.frame.union(self.iconFrame).insetBy(dx: -12, dy: -12)
            if zone.contains(NSEvent.mouseLocation) {
                self.outsideTicks = 0
            } else {
                self.outsideTicks += 1
                if self.outsideTicks >= 2 { self.hide() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        watcher = timer
    }
}

private struct DockAppCardView: View {
    let content: DockAppCard.Content
    let app: NSRunningApplication
    let close: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var calendar = NotchCalendarService.shared

    private var text: DockExtrasFeatureStrings { FeatureStrings.dockExtras(l10n.language) }

    var body: some View {
        Group {
            switch content {
            case .music: musicCard
            case .calendar: calendarCard
            }
        }
        .padding(12)
        .background(HUDBackdrop(cornerRadius: 16, opacity: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private var musicCard: some View {
        let playback = music.playback
        return HStack(spacing: 12) {
            Group {
                if let artwork = music.artwork {
                    Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
                } else if let icon = app.icon {
                    Image(nsImage: icon).resizable()
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture { open() }
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(playback?.track.title ?? app.localizedName ?? "")
                        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(playback?.track.artist ?? "")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 18) {
                    control("backward.fill", .previous)
                    control(playback?.isPlaying == true ? "pause.fill" : "play.fill", .toggle)
                    control("forward.fill", .next)
                }
            }
            .frame(width: 180, alignment: .leading)
        }
    }

    private func control(_ symbol: String, _ command: NotchPlaybackCommand) -> some View {
        Button {
            _ = music.send(command)
        } label: {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).frame(width: 22, height: 18)
        }
        .buttonStyle(.plain)
        .disabled(!music.canPerform(command))
    }

    private var calendarCard: some View {
        let today = BoringNotchCalendarSupport.events(calendar.events, on: Date())
        return VStack(alignment: .leading, spacing: 8) {
            Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.system(size: 13, weight: .semibold))
                .onTapGesture { open() }
            if today.isEmpty {
                Text(text.nothingToday).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(today.prefix(5), id: \.id) { event in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: event.color.red, green: event.color.green, blue: event.color.blue))
                        .frame(width: 3, height: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        if event.allDay {
                            Text(text.allDay).font(.system(size: 10.5)).foregroundStyle(.secondary)
                        } else {
                            Text("\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 10.5)).foregroundStyle(.secondary)
                        }
                    }
                }
                .opacity(event.end < Date() ? 0.55 : 1)
            }
        }
        .frame(width: 240, alignment: .leading)
    }

    private func open() {
        if app.isHidden { app.unhide() }
        app.activate()
        close()
    }
}
