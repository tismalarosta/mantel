// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Mirror tile from Boring Notch (github.com/TheBoredTeam/boring.notch, GPL-3.0):
// boringNotch/components/Webcam/WebcamView.swift.

import AVFoundation
import SwiftUI

/// Boring Notch's mirror on Vorssaint's camera: a square or round tile,
/// dark with the camera glyph until clicked, then the mirrored image; click
/// again to stop. Vorssaint's camera service owns the camera, its permission
/// and its device choice; this view only shows its session.
struct BoringNotchMirrorView: View {
    let shape: BoringNotchMirrorShape
    let size: CGSize
    @ObservedObject private var camera = CameraPreviewService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let side = max(0, min(size.width, size.height))
        let radius = shape.cornerRadius(side: side)
        let running = camera.isEmbeddedPresented && camera.state == .running && camera.session != nil
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(red: 20 / 255, green: 20 / 255, blue: 20 / 255))
                .strokeBorder(.white.opacity(0.04), lineWidth: 1)
            if running, let session = camera.session {
                BoringNotchMirrorLayer(session: session)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: side / 3.5))
                    Text(caption)
                        .font(.caption2)
                }
                .foregroundStyle(.gray)
            }
        }
        .frame(width: side, height: side)
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .onTapGesture(perform: toggle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
        .onDisappear { camera.hideEmbedded() }
    }

    private var symbol: String {
        switch camera.state {
        case .denied, .unavailable: return "exclamationmark.triangle"
        case .noCamera: return "video.slash"
        default: return "web.camera"
        }
    }

    private var caption: String {
        let text = FeatureStrings.notchActivities(l10n.language)
        switch camera.state {
        case .denied: return FeatureStrings.cameraPreview(l10n.language).deniedMessage
        case .unavailable: return text.cameraUnavailable
        case .noCamera: return FeatureStrings.cameraPreview(l10n.language).noCameraMessage
        default: return BoringNotchTabStrings.localized(l10n.language).mirror
        }
    }

    private func toggle() {
        if camera.isEmbeddedPresented {
            camera.hideEmbedded()
        } else if camera.state == .denied {
            Permissions.shared.openCameraSettings()
        } else {
            camera.showEmbedded()
        }
    }
}

/// The session's preview layer, mirrored as Vorssaint's own mirror is.
private struct BoringNotchMirrorLayer: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        view.wantsLayer = true
        mirror(layer)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let layer = view.layer as? AVCaptureVideoPreviewLayer else { return }
        if layer.session !== session { layer.session = session }
        mirror(layer)
    }

    /// The connection exists once the session has its input, so the flip is
    /// applied on every update.
    private func mirror(_ layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection, connection.isVideoMirroringSupported else { return }
        if connection.automaticallyAdjustsVideoMirroring { connection.automaticallyAdjustsVideoMirroring = false }
        if !connection.isVideoMirrored { connection.isVideoMirrored = true }
    }
}
