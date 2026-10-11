// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Options follow Mac Duo's controls (github.com/DhananjayBhosale/MacDuo, MIT).

import SwiftUI

/// The lid animation's card on the Energy page, drawn like its neighbours:
/// one row per option, the control on the right.
struct LidAnimationSettingsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = LidAnimationService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.lidAnimationEnabled) private var enabled = false
    @AppStorage(DefaultsKey.lidAnimationEffect) private var effect = FoldEffect.fallback.rawValue
    @AppStorage(DefaultsKey.lidAnimationClearAngle) private var clearAngle = LidAnimationSupport.defaultClearAngle
    @AppStorage(DefaultsKey.lidAnimationClearWhenStill) private var clearWhenStill = true
    @AppStorage(DefaultsKey.lidAnimationStillnessDelay)
    private var stillnessDelay = LidAnimationSupport.defaultStillnessDelay
    @AppStorage(DefaultsKey.lidAnimationPerspective) private var perspective = LidAnimationSupport.defaultPerspective
    @AppStorage(DefaultsKey.lidAnimationSoftness) private var softness = LidAnimationSupport.defaultSoftness
    @AppStorage(DefaultsKey.lidAnimationShadow) private var shadow = LidAnimationSupport.defaultShadow

    private var text: LidAnimationFeatureStrings {
        FeatureStrings.lidAnimation(l10n.language)
    }

    private var selectedEffect: FoldEffect { FoldEffect.resolve(persisted: effect) }

    var body: some View {
        SettingsCard {
            SettingsRow(symbol: "macbook", title: text.enable, caption: text.enableCaption) {
                Toggle(text.enable, isOn: $enabled)
                    .labelsHidden()
                    .onChange(of: enabled) { _, _ in
                        LidAnimationService.shared.syncWithPreferences()
                    }
            }
            if enabled {
                if let message = statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(statusIsWarning ? Color.orange : Color.secondary)
                        .padding(.leading, settingsRowTextInset)
                }
                if service.status == .needsAccess || !permissions.screenRecording {
                    PermissionRow(kind: .screenRecording)
                }
                if service.status != .unsupported && service.status != .noMetal {
                    options
                }
            }
        }
        .onAppear { LidAnimationService.shared.recheckAccess() }
        .onChange(of: permissions.screenRecording) { _, granted in
            if granted { LidAnimationService.shared.recheckAccess() }
        }
    }

    @ViewBuilder
    private var options: some View {
        SettingsRow(symbol: selectedEffect.symbol, title: text.effectTitle,
                    caption: text.summary(for: selectedEffect)) {
            Picker(text.effectTitle, selection: effectBinding) {
                ForEach(FoldEffect.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
        sliderRow(symbol: "angle", title: text.clearsAt, caption: text.clearsAtCaption,
                  value: unitBinding($clearAngle, range: LidAnimationSupport.clearAngleRange,
                                     fallback: LidAnimationSupport.defaultClearAngle),
                  range: LidAnimationSupport.clearAngleRange, step: 1,
                  label: "\(Int(LidAnimationSupport.sanitizedClearAngle(clearAngle).rounded()))°")
        SettingsRow(symbol: "pause.circle", title: text.clearWhenStill, caption: text.clearWhenStillCaption) {
            Toggle(text.clearWhenStill, isOn: $clearWhenStill).labelsHidden()
        }
        if clearWhenStill {
            sliderRow(symbol: "timer", title: String(format: text.clearAfterFormat,
                                                     Int(LidAnimationSupport.sanitizedStillnessDelay(stillnessDelay))),
                      caption: nil,
                      value: unitBinding($stillnessDelay, range: LidAnimationSupport.stillnessDelayRange,
                                         fallback: LidAnimationSupport.defaultStillnessDelay),
                      range: LidAnimationSupport.stillnessDelayRange, step: 1, label: nil)
        }
        sliderRow(symbol: "perspective", title: text.perspective, caption: nil,
                  value: unitBinding($perspective, range: LidAnimationSupport.unitRange,
                                     fallback: LidAnimationSupport.defaultPerspective),
                  range: LidAnimationSupport.unitRange, step: nil, label: percent(perspective))
        sliderRow(symbol: "drop", title: text.softness, caption: nil,
                  value: unitBinding($softness, range: LidAnimationSupport.unitRange,
                                     fallback: LidAnimationSupport.defaultSoftness),
                  range: LidAnimationSupport.unitRange, step: nil, label: percent(softness))
        sliderRow(symbol: "shadow", title: text.shadow, caption: nil,
                  value: unitBinding($shadow, range: LidAnimationSupport.unitRange,
                                     fallback: LidAnimationSupport.defaultShadow),
                  range: LidAnimationSupport.unitRange, step: nil, label: percent(shadow))
        SettingsRow(symbol: "play.rectangle", title: text.testDesktop, caption: text.testDesktopCaption) {
            Button(text.testDesktop) { LidAnimationService.shared.testDesktop() }
                .disabled(service.status == .testing || service.status == .needsAccess
                          || service.status == .checkingAccess)
        }
        ShortcutPreferenceRow(role: .lidAnimationPause, isEnabled: enabled) {
            LidAnimationService.shared.syncWithPreferences()
        }
        Text(text.pauseShortcutCaption)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, settingsRowTextInset)
        if service.pauseShortcutRegistrationFailed {
            Text(l10n.s.shortcutUnavailable)
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.leading, settingsRowTextInset)
        }
    }

    private func sliderRow(symbol: String, title: String, caption: String?, value: Binding<Double>,
                           range: ClosedRange<Double>, step: Double?, label: String?) -> some View {
        SettingsRow(symbol: symbol, title: title, caption: caption) {
            HStack(spacing: 8) {
                if let step {
                    Slider(value: value, in: range, step: step)
                } else {
                    Slider(value: value, in: range)
                }
                if let label {
                    Text(label)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 40, alignment: .trailing)
                }
            }
            .frame(width: 220)
        }
    }

    private func unitBinding(_ stored: Binding<Double>, range: ClosedRange<Double>,
                             fallback: Double) -> Binding<Double> {
        Binding(
            get: { LidAnimationSupport.clamped(stored.wrappedValue, to: range, fallback: fallback) },
            set: { stored.wrappedValue = LidAnimationSupport.clamped($0, to: range, fallback: fallback) }
        )
    }

    private var effectBinding: Binding<FoldEffect> {
        Binding(get: { selectedEffect }, set: { effect = $0.persistedIdentifier })
    }

    private func percent(_ value: Double) -> String {
        "\(Int((LidAnimationSupport.sanitizedUnit(value, fallback: 0) * 100).rounded()))%"
    }

    private var statusMessage: String? {
        switch service.status {
        case .off: return nil
        case .unsupported: return text.unsupported
        case .noMetal: return text.noMetal
        case .checkingAccess: return text.statusCheckingAccess
        case .needsAccess: return text.statusNeedsAccess
        case .following: return text.statusFollowing
        case .still: return text.statusStill
        case .paused: return text.statusPaused
        case .testing: return text.statusTesting
        case .waitingForSensor: return text.statusWaitingForSensor
        case .waitingForDisplay: return text.statusWaitingForDisplay
        case .captureFailed(let reason): return String(format: text.statusCaptureFailedFormat, reason)
        }
    }

    private var statusIsWarning: Bool {
        switch service.status {
        case .unsupported, .noMetal, .needsAccess, .captureFailed: return true
        default: return false
        }
    }
}
