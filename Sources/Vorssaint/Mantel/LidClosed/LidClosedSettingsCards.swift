// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import SwiftUI

/// Stay Online's card on the Energy page, under Keep Awake.
struct NetworkFallbackSettingsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = NetworkFallbackService.shared
    @AppStorage(DefaultsKey.networkFallbackRestartWiFi) private var restart = true
    @State private var addSelection = ""

    private var text: LidClosedFeatureStrings { FeatureStrings.lidClosed(l10n.language) }

    var body: some View {
        SettingsCard(title: text.onlineTitle) {
            LidClosedStatusLine(text: statusText, tone: statusTone)
            SettingsRow(symbol: "location.fill", title: text.location, caption: text.locationCaption) {
                if service.hasLocation {
                    Text(text.locationAllowed).foregroundStyle(.secondary)
                } else {
                    Button(service.locationStatus == .notDetermined ? text.locationAllow : text.locationDenied) {
                        service.requestLocation()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Divider()
            SettingsRow(symbol: "list.bullet", title: text.order, caption: text.orderCaption) { EmptyView() }
            VStack(alignment: .leading, spacing: 8) {
                networkList
                HStack(spacing: 8) {
                    Picker(text.add, selection: $addSelection) {
                        ForEach(addable, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(addable.isEmpty)
                    Button(text.add) {
                        let pick = addable.contains(addSelection) ? addSelection : addable.first
                        if let pick { service.priority.append(pick) }
                    }
                    .disabled(addable.isEmpty)
                    Text(text.addCaption).font(.caption).foregroundStyle(.secondary)
                }
                Text(text.loginNote).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !service.missingLogins.isEmpty {
                    Text(text.loginMissingHelp).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, settingsRowTextInset)
            .disabled(!service.hasLocation)
            .opacity(service.hasLocation ? 1 : 0.45)
            Divider()
            SettingsRow(symbol: "iphone", title: text.hotspot, caption: text.hotspotCaption) { EmptyView() }
            HStack(spacing: 12) {
                Text(text.hotspotHelp).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(text.openWiFiSettings) { service.openWiFiSettings() }
            }
            .padding(.leading, settingsRowTextInset)
            Divider()
            SettingsRow(symbol: "arrow.triangle.2.circlepath", title: text.restart, caption: text.restartCaption) {
                Toggle(text.restart, isOn: $restart).labelsHidden()
            }
        }
        .onAppear { service.refreshKnownNetworks() }
    }

    private var addable: [String] {
        let listed = Set(service.priority)
        return service.knownNetworks.filter { !listed.contains($0) }
    }

    private var networkList: some View {
        VStack(spacing: 0) {
            if service.priority.isEmpty {
                Text(text.orderEmpty).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            ForEach(Array(service.priority.enumerated()), id: \.element) { index, ssid in
                if index > 0 { Divider() }
                networkRow(index: index, ssid: ssid)
            }
        }
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func networkRow(index: Int, ssid: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
            Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 16, alignment: .trailing)
            Image(systemName: "wifi").foregroundStyle(.secondary)
            Text(ssid).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            if service.allowedLogins.contains(ssid) {
                Label(text.loginAllowed, systemImage: "key.fill")
                    .font(.caption).foregroundStyle(.green)
            } else if service.missingLogins.contains(ssid) {
                Label(text.loginMissing, systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
                    .help(text.loginMissingHelp)
            } else {
                Button(text.loginAllow) { service.allowLogin(for: ssid) }
                    .controlSize(.small)
            }
            Button {
                service.priority.removeAll { $0 == ssid }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help(text.remove)
            .accessibilityLabel("\(text.remove) \(ssid)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .draggable(ssid)
        .dropDestination(for: String.self) { items, _ in
            guard let moved = items.first, moved != ssid else { return false }
            var list = service.priority
            list.removeAll { $0 == moved }
            list.insert(moved, at: list.firstIndex(of: ssid) ?? list.count)
            service.priority = list
            return true
        }
    }

    private var statusText: String {
        switch service.status {
        case .off, .waitingForSession: return text.waitingSession
        case .waitingForLid: return text.waitingLid
        case .noWiFi: return text.noWiFi
        case .wifiOff: return text.runningWifiOff
        case .onHotspot: return text.runningOnHotspot
        case .on(let ssid): return String(format: text.runningOnFormat, ssid ?? "Wi-Fi")
        case .offline(let since):
            return String(format: text.runningOfflineFormat, Int(Date().timeIntervalSince(since)))
        }
    }

    private var statusTone: LidClosedStatusLine.Tone {
        switch service.status {
        case .on: return .good
        case .onHotspot, .offline, .wifiOff: return .warning
        default: return .idle
        }
    }
}

/// Lid Pause's card on the Energy page, under Stay Online.
struct LidPauseSettingsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = LidPauseService.shared
    @State private var addSelection = ""
    @State private var running: [(id: String, name: String)] = []

    private var text: LidClosedFeatureStrings { FeatureStrings.lidClosed(l10n.language) }

    var body: some View {
        SettingsCard(title: text.pauseTitle) {
            SettingsRow(symbol: "pause.circle", title: text.pauseEverything, caption: text.pauseCaption) {
                EmptyView()
            }
            Divider()
            SettingsRow(symbol: "list.bullet", title: text.keep, caption: text.keepCaption) { EmptyView() }
            VStack(alignment: .leading, spacing: 8) {
                LidClosedChips(items: service.keepList.map { ($0, LidPauseService.appName(for: $0)) },
                               removeLabel: text.remove) { id in
                    service.keepList.removeAll { $0 == id }
                    refreshRunning()
                }
                HStack(spacing: 8) {
                    Picker(text.add, selection: $addSelection) {
                        ForEach(running, id: \.id) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(running.isEmpty)
                    Button(text.add) {
                        let pick = running.first { $0.id == addSelection } ?? running.first
                        if let pick { service.keepList.append(pick.id) }
                        refreshRunning()
                    }
                    .disabled(running.isEmpty)
                    Text(text.keepAddCaption).font(.caption).foregroundStyle(.secondary)
                }
                Text(summary).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, settingsRowTextInset)
        }
        .onAppear(perform: refreshRunning)
    }

    private var summary: String {
        if !service.pausedApps.isEmpty {
            return String(format: text.pausedNowFormat, service.pausedApps.joined(separator: ", "))
        }
        guard !running.isEmpty else { return text.nothingToPause }
        return String(format: text.wouldPauseFormat, running.map(\.name).joined(separator: ", "))
    }

    private func refreshRunning() {
        running = service.runningPausable()
    }
}

/// The one-line state at the top of Stay Online's card.
struct LidClosedStatusLine: View {
    enum Tone { case good, warning, idle }
    let text: String
    let tone: Tone

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tone == .good ? Color.green : tone == .warning ? Color.orange : Color.secondary)
                .frame(width: 8, height: 8)
            Text(text).font(.callout)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// App names as removable capsules, wrapping to the next line.
private struct LidClosedChips: View {
    let items: [(id: String, name: String)]
    let removeLabel: String
    let onRemove: (String) -> Void

    var body: some View {
        LidClosedFlow(spacing: 6) {
            ForEach(items, id: \.id) { item in
                HStack(spacing: 4) {
                    Text(item.name)
                    Button { onRemove(item.id) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(removeLabel) \(item.name)")
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 3)
                .background(.background.opacity(0.5), in: Capsule())
                .overlay(Capsule().strokeBorder(.separator))
            }
        }
    }
}

/// A left-aligned wrapping row.
private struct LidClosedFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
