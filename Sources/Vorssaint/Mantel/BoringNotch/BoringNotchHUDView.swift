// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// components/Live activities/InlineHUD.swift, SystemEventIndicatorModifier.swift,
// BoringBattery.swift (BoringBatteryView, BatteryMenuView), ContentView.swift (sneak peek).

import AppKit
import SwiftUI

/// Localized strings for the Boring Notch HUD, battery and fullscreen
/// options. English and French are written; other languages read English.
struct BoringNotchHUDStrings {
    let volume, brightness, backlight, mic, muted, unmuted: String
    let hudStyle, hudInline, hudBelow, hudCaption: String
    let fullscreen, fullscreenAll, fullscreenMedia, fullscreenNever, fullscreenCaption: String
    let battery, charging, pluggedIn, onBattery, lowPower, batterySettings: String

    static func localized(_ language: AppLanguage) -> BoringNotchHUDStrings { language == .fr ? .fr : .enUS }

    static let enUS = BoringNotchHUDStrings(
        volume: "Volume", brightness: "Brightness", backlight: "Backlight", mic: "Mic",
        muted: "muted", unmuted: "unmuted",
        hudStyle: "Volume and brightness", hudInline: "Inside the notch", hudBelow: "Below the notch",
        hudCaption: "How the notch shows the volume, brightness, keyboard light and mic.",
        fullscreen: "Hide in fullscreen", fullscreenAll: "All apps", fullscreenMedia: "Media app only",
        fullscreenNever: "Never",
        fullscreenCaption: "Media app only hides the notch over the app playing the music.",
        battery: "Battery", charging: "Charging", pluggedIn: "Plugged in", onBattery: "On battery",
        lowPower: "Low Power Mode", batterySettings: "Battery Settings…")

    static let fr = BoringNotchHUDStrings(
        volume: "Volume", brightness: "Luminosité", backlight: "Rétroéclairage", mic: "Micro",
        muted: "coupé", unmuted: "actif",
        hudStyle: "Volume et luminosité", hudInline: "Dans l’encoche", hudBelow: "Sous l’encoche",
        hudCaption: "Comment l’encoche affiche le volume, la luminosité, le clavier et le micro.",
        fullscreen: "Masquer en plein écran", fullscreenAll: "Toutes les apps", fullscreenMedia: "App de musique seulement",
        fullscreenNever: "Jamais",
        fullscreenCaption: "App de musique seulement masque l’encoche au-dessus de l’app qui joue la musique.",
        battery: "Batterie", charging: "En charge", pluggedIn: "Branché", onBattery: "Sur batterie",
        lowPower: "Mode économie d’énergie", batterySettings: "Réglages de la batterie…")
}

/// A volume, brightness, keyboard light or mic notice in Boring Notch's
/// HUD. The bar can be dragged, through Vorssaint's own mixer and
/// brightness service (the key taps stay theirs, SPEC rule 4).
struct BoringNotchHUDView: View {
    let notice: NotchNotice
    let geometry: NotchGeometry
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchBoringHUDStyle) private var storedStyle = BoringNotchHUDStyle.fallback.rawValue
    @State private var dragged: Double?

    private var text: BoringNotchHUDStrings { BoringNotchHUDStrings.localized(l10n.language) }
    private var value: Double { dragged ?? notice.level ?? 0 }
    private var style: BoringNotchHUDStyle { BoringNotchHUDStyle.sanitized(storedStyle) }

    private var name: String {
        switch notice.event {
        case .volume: return text.volume
        case .brightness: return text.brightness
        case .keyboardLight: return text.backlight
        case .microphone: return text.mic
        default: return notice.title
        }
    }

    var body: some View {
        switch style {
        case .inline: inline
        case .below: below
        }
    }

    private var mark: some View {
        Image(systemName: BoringNotchHUDSupport.symbol(for: notice.event, level: notice.level))
            .contentTransition(.symbolEffect(.replace))
            .foregroundStyle(.white)
            .frame(width: 20, height: 15)
    }

    /// InlineHUD: mark and name left of the camera, the bar right of it.
    private var inline: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                mark
                Text(name).font(.subheadline).fontWeight(.medium).lineLimit(1).allowsTightening(true)
            }
            .padding(.leading, 10)
            .frame(width: BoringNotchHUDSupport.inlineWing, alignment: .leading)
            Color.clear.frame(width: geometry.cameraWidth)
            reading
                .padding(.trailing, 10)
                .frame(width: BoringNotchHUDSupport.inlineWing)
        }
        .frame(height: geometry.stripHeight)
    }

    /// The default style: the notch stays itself, the reading drops below it.
    private var below: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: geometry.stripHeight)
            HStack(spacing: 8) {
                mark
                reading
            }
            .padding(.horizontal, 14)
            .frame(height: BoringNotchHUDSupport.belowBand)
        }
    }

    @ViewBuilder private var reading: some View {
        if notice.event == .microphone || notice.level == nil {
            Text(notice.event == .microphone ? (value > 0 ? text.unmuted : text.muted) : notice.detail)
                .font(.caption).fontWeight(.medium).foregroundStyle(.gray).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            HStack(spacing: 6) {
                BoringNotchProgressBar(value: value, draggable: canDrag) { next in
                    dragged = next
                    apply(next)
                } ended: { dragged = nil }
                Text(notice.event == .volume && value <= 0 ? text.muted : "\(Int((value * 100).rounded()))%")
                    .font(.caption).fontWeight(.medium).foregroundStyle(.gray).monospacedDigit()
                    .lineLimit(1).frame(minWidth: 30, alignment: .trailing)
            }
        }
    }

    private var canDrag: Bool { notice.event == .volume || notice.event == .brightness }

    private func apply(_ value: Double) {
        switch notice.event {
        case .volume: AppVolumeMixer.setSystemOutputVolume(value)
        case .brightness: BrightnessService.shared.setBrightness(value, for: CGMainDisplayID())
        default: break
        }
    }
}

/// Boring Notch's DraggableProgressBar: a capsule that thickens under the drag.
struct BoringNotchProgressBar: View {
    let value: Double
    let draggable: Bool
    let changed: (Double) -> Void
    let ended: () -> Void
    @State private var dragging = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule().fill(Color.white).frame(width: proxy.size.width * min(1, max(0, value)))
            }
            .frame(height: dragging ? 8 : 5)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard draggable else { return }
                    dragging = true
                    changed(Double(min(max(0, drag.location.x / max(1, proxy.size.width)), 1)))
                }
                .onEnded { _ in dragging = false; ended() })
            .animation(.smooth(duration: 0.15), value: dragging)
        }
    }
}

/// Boring Notch's plug-in banner: the status on the left of the camera, the
/// battery on the right.
struct BoringNotchBatteryBanner: View {
    let notice: NotchNotice
    let geometry: NotchGeometry
    @ObservedObject var service: NotchService

    var body: some View {
        HStack(spacing: 0) {
            Text(notice.title).font(.subheadline).foregroundStyle(.white).lineLimit(1)
                .padding(.leading, 12)
                .frame(width: BoringNotchHUDSupport.batteryWing, alignment: .leading)
            Color.clear.frame(width: geometry.cameraWidth)
            HStack(spacing: 6) {
                if !notice.detail.isEmpty {
                    Text(notice.detail).font(.caption).foregroundStyle(.gray).monospacedDigit()
                }
                BoringNotchBatteryGlyph(percent: service.power.chargePercent, charging: service.power.isCharging,
                                        plugged: service.power.externalConnected)
            }
            .padding(.trailing, 12)
            .frame(width: BoringNotchHUDSupport.batteryWing, alignment: .trailing)
        }
        .frame(height: geometry.stripHeight)
    }
}

/// Boring Notch's sneak peek on a song change: the notch stays, a line
/// with the song and artist shows below it.
struct BoringNotchSneakPeek: View {
    let notice: NotchNotice
    let geometry: NotchGeometry

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: geometry.stripHeight)
            HStack(spacing: 6) {
                Image(systemName: "music.note")
                Text([notice.title, notice.detail].filter { !$0.isEmpty }.joined(separator: " – "))
                    .lineLimit(1).truncationMode(.tail)
            }
            .font(.subheadline)
            .foregroundStyle(.gray)
            .padding(.horizontal, 14)
            .frame(height: BoringNotchHUDSupport.sneakPeekBand)
        }
    }
}

/// BoringBatteryView: an outline with its fill, a bolt while charging.
struct BoringNotchBatteryGlyph: View {
    let percent: Int?
    let charging: Bool
    let plugged: Bool
    var width: CGFloat = 26

    var body: some View {
        let fill = BoringNotchHUDSupport.batteryFill(percent: percent)
        let tint: Color = switch BoringNotchHUDSupport.batteryTint(percent: percent, charging: charging, plugged: plugged) {
        case .charging: .green
        case .low: .red
        case .normal: .white
        }
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: max(0, (width - 4) * fill))
                    .padding(2)
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: width, height: width * 0.5)
            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.5)).frame(width: 1.5, height: width * 0.18)
        }
        .accessibilityLabel(percent.map { "\($0)%" } ?? "")
    }
}

/// The battery in the open header, with Boring Notch's battery menu.
struct BoringNotchHeaderBattery: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var l10n = L10n.shared
    @State private var showsMenu = false

    private var text: BoringNotchHUDStrings { BoringNotchHUDStrings.localized(l10n.language) }

    var body: some View {
        let power = service.power
        if power.chargePercent != nil {
            Button { showsMenu.toggle() } label: {
                BoringNotchBatteryGlyph(percent: power.chargePercent, charging: power.isCharging,
                                        plugged: power.externalConnected, width: 30)
                    .frame(height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showsMenu, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(text.battery).font(.headline)
                        Spacer()
                        Text(power.chargePercent.map { "\($0)%" } ?? "").font(.headline).monospacedDigit()
                    }
                    Text(power.isCharging ? text.charging : power.externalConnected ? text.pluggedIn : text.onBattery)
                        .foregroundStyle(.secondary)
                    if ProcessInfo.processInfo.isLowPowerModeEnabled {
                        Label(text.lowPower, systemImage: "leaf.fill").foregroundStyle(.yellow)
                    }
                    Divider()
                    Button(text.batterySettings) {
                        showsMenu = false
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                .padding(14)
                .frame(width: 220)
            }
        }
    }
}

/// The HUD and fullscreen choices, in the Design card while Boring Notch
/// is the design.
struct BoringNotchHUDOptions: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchBoringHUDStyle) private var style = BoringNotchHUDStyle.fallback.rawValue
    @AppStorage(DefaultsKey.notchBoringFullscreen) private var fullscreen = BoringNotchFullscreenPolicy.fallback.rawValue

    private var text: BoringNotchHUDStrings { BoringNotchHUDStrings.localized(l10n.language) }

    var body: some View {
        SettingsRow(symbol: "speaker.wave.2", title: text.hudStyle, caption: text.hudCaption) {
            Picker(text.hudStyle, selection: $style) {
                Text(text.hudInline).tag(BoringNotchHUDStyle.inline.rawValue)
                Text(text.hudBelow).tag(BoringNotchHUDStyle.below.rawValue)
            }
            .labelsHidden().fixedSize()
        }
        SettingsRow(symbol: "arrow.up.left.and.arrow.down.right", title: text.fullscreen,
                    caption: text.fullscreenCaption) {
            Picker(text.fullscreen, selection: $fullscreen) {
                Text(text.fullscreenAll).tag(BoringNotchFullscreenPolicy.allApps.rawValue)
                Text(text.fullscreenMedia).tag(BoringNotchFullscreenPolicy.mediaApp.rawValue)
                Text(text.fullscreenNever).tag(BoringNotchFullscreenPolicy.never.rawValue)
            }
            .labelsHidden().fixedSize()
        }
        .onChange(of: fullscreen) { _, _ in NotchService.shared.syncWithPreferences() }
    }
}
