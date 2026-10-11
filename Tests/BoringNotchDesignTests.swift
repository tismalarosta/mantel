// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import CoreGraphics
import Foundation

/// Slice 5a of the Boring Notch design: the setting, Boring Notch's numbers,
/// its outline, and the hooks that keep it a view layer on Vorssaint's island.
enum BoringNotchDesignTests {
    static func run(_ suite: TestSuite) {
        setting(suite)
        metrics(suite)
        outline(suite)
        hooks(suite)
        music(suite)
        hud(suite)
    }

    /// Slice 5c: HUD styles, battery, sneak peek and fullscreen.
    private static func hud(_ suite: TestSuite) {
        typealias H = BoringNotchHUDSupport
        suite.expect(BoringNotchHUDStyle.sanitized(nil) == .inline
                        && Defaults.registeredDefaults[DefaultsKey.notchBoringHUDStyle] as? String == "inline",
                     "the HUD starts inside the notch (Matisse, 2026-10-11)")
        suite.expect([NotchEvent.volume, .brightness, .keyboardLight, .microphone].allSatisfy(H.isHUD)
                        && !H.isHUD(.battery) && !H.isHUD(.clipboard) && !H.isHUD(.track),
                     "volume, brightness, keyboard light and mic are Boring Notch HUDs")
        suite.expect(H.size(for: .volume, style: .inline, cameraWidth: 180, stripHeight: 32)
                        == CGSize(width: 380, height: 32),
                     "the inline HUD widens the notch by Boring Notch's 100 pt on each side")
        suite.expect(H.size(for: .brightness, style: .below, cameraWidth: 180, stripHeight: 32)
                        == CGSize(width: 260, height: 62),
                     "the below style keeps the notch and drops a 30 pt band under it")
        suite.expect(H.size(for: .battery, style: .inline, cameraWidth: 180, stripHeight: 32)?.width == 440
                        && H.size(for: .track, style: .inline, cameraWidth: 180, stripHeight: 32)?.height == 54,
                     "battery shows as a wide banner, a song change as a line below the notch")
        suite.expect(H.size(for: .clipboard, style: .inline, cameraWidth: 180, stripHeight: 32) == nil
                        && H.size(for: .systemNotification, style: .below, cameraWidth: 180, stripHeight: 32) == nil,
                     "other notices keep Vorssaint's layout")
        suite.expect(H.symbol(for: .volume, level: 0) == "speaker.slash.fill"
                        && H.symbol(for: .volume, level: 0.2) == "speaker.wave.1.fill"
                        && H.symbol(for: .volume, level: 0.5) == "speaker.wave.2.fill"
                        && H.symbol(for: .volume, level: 0.9) == "speaker.wave.3.fill"
                        && H.symbol(for: .brightness, level: 0.4) == "sun.min.fill"
                        && H.symbol(for: .brightness, level: 0.8) == "sun.max.fill",
                     "HUD marks follow the level like Boring Notch's")
        suite.expect(H.batteryTint(percent: 15, charging: false, plugged: false) == .low
                        && H.batteryTint(percent: 15, charging: true, plugged: true) == .charging
                        && H.batteryTint(percent: 60, charging: false, plugged: false) == .normal
                        && H.batteryFill(percent: 140) == 1 && H.batteryFill(percent: nil) == 0,
                     "the battery is red at 20 % or below, green while charging, its fill clamped")
        suite.expect(BoringNotchFullscreenPolicy.sanitized(nil) == .mediaApp,
                     "Boring Notch hides over the media app by default")
        suite.expect(H.hidesInFullscreen(policy: .allApps, isFullscreen: true, frontmostBundleID: "a", playerBundleID: "b")
                        && !H.hidesInFullscreen(policy: .allApps, isFullscreen: false, frontmostBundleID: "a", playerBundleID: "a")
                        && !H.hidesInFullscreen(policy: .never, isFullscreen: true, frontmostBundleID: "a", playerBundleID: "a")
                        && H.hidesInFullscreen(policy: .mediaApp, isFullscreen: true,
                                               frontmostBundleID: "com.spotify.client", playerBundleID: "com.spotify.client")
                        && !H.hidesInFullscreen(policy: .mediaApp, isFullscreen: true,
                                                frontmostBundleID: "com.apple.Safari", playerBundleID: "com.spotify.client")
                        && !H.hidesInFullscreen(policy: .mediaApp, isFullscreen: true,
                                                frontmostBundleID: "com.apple.Safari", playerBundleID: nil),
                     "fullscreen hiding: all apps, only over the music player, or never")
        func source(_ path: String) -> String { (try? String(contentsOfFile: path, encoding: .utf8)) ?? "" }
        let hudView = source("Sources/Vorssaint/Mantel/BoringNotch/BoringNotchHUDView.swift")
        suite.expect(hudView.contains("AppVolumeMixer.setSystemOutputVolume")
                        && hudView.contains("BrightnessService.shared.setBrightness")
                        && !hudView.contains("tapCreate") && !hudView.contains("CGEvent"),
                     "dragging the HUD goes through Vorssaint's mixer and brightness service; no key tap of its own")
        let service = source("Sources/Vorssaint/Services/Notch/NotchService.swift")
        suite.expect(service.contains("(expanded && NotchDesign.isBoringNotch && !showingSections && !showingCommandBar)"),
                     "music runs while Boring Notch's Home tab is open")
    }

    /// Slice 5b: the player's slots, labels and pick-one choices.
    private static func music(_ suite: TestSuite) {
        typealias Slot = BoringNotchMusicSlot
        suite.expect(Slot.defaultLayout == [.none, .previous, .playPause, .next, .none]
                        && Defaults.registeredDefaults[DefaultsKey.notchBoringMusicSlots] as? String
                            == Slot.stored(Slot.defaultLayout)
                        && Defaults.registeredDefaults[DefaultsKey.notchBoringMusicSlotCount] as? Int == 5,
                     "the player starts with Boring Notch's five slots: empty, previous, play, next, empty")
        suite.expect(Slot.layout(from: "shuffle,next", count: 4) == [.shuffle, .next, .none, .none],
                     "a short layout is padded with empty slots")
        suite.expect(Slot.layout(from: "previous,playPause,next,volume,shuffle", count: 3)
                        == [.previous, .playPause, .next],
                     "a long layout is cut to the slot count")
        suite.expect(Slot.layout(from: "bogus,favorite,next", count: 3) == [.next, .none, .none]
                        && Slot.layout(from: nil, count: 9).count == 5 && Slot.layout(from: "", count: 1).count == 3,
                     "unknown slots are dropped and the count stays between 3 and 5")
        suite.expect(Slot.layout(from: Slot.stored([.goBackward, .playPause, .goForward]), count: 3)
                        == [.goBackward, .playPause, .goForward],
                     "a layout survives the trip to disk")
        suite.expect(!Slot.pickerOptions.isEmpty && Slot.allCases.allSatisfy { !$0.symbol.isEmpty },
                     "every slot has a picker entry and a symbol")
        typealias S = BoringNotchMusicSupport
        suite.expect(S.timeString(0) == "0:00" && S.timeString(65) == "1:05" && S.timeString(3725) == "1:02:05"
                        && S.timeString(.nan) == "0:00",
                     "slider times read m:ss, and h:mm:ss past an hour")
        suite.expect(S.skipTarget(position: 10, by: -15, duration: 200) == 0
                        && S.skipTarget(position: 195, by: 15, duration: 200) == 200
                        && S.skipTarget(position: 50, by: 15, duration: 200) == 65,
                     "15 s skips stay inside the track")
        suite.expect(S.visualizer(nil) == .boringNotch && S.visualizer("vorssaint") == .vorssaint
                        && S.lyricsStyle(nil) == .boringNotch && S.lyricsStyle("vorssaint") == .vorssaint,
                     "the pick-one choices default to Boring Notch (SPEC §3D)")
        func source(_ path: String) -> String { (try? String(contentsOfFile: path, encoding: .utf8)) ?? "" }
        let player = source("Sources/Vorssaint/Mantel/BoringNotch/BoringNotchPlayerView.swift")
        suite.expect(player.contains("NotchQueueView(playback: playback)")
                        && player.contains("NotchMusicService.shared") && !player.contains("MRMediaRemote"),
                     "the player shows Vorssaint's Up Next and reads Vorssaint's Now Playing bridge only")
        let service = source("Sources/Vorssaint/Services/Notch/NotchService.swift")
        suite.expect(service.contains("showsContent: !NotchDesign.isBoringNotch"),
                     "Boring Notch rests as a bare notch, without Vorssaint's resting extras")
    }

    private static func setting(_ suite: TestSuite) {
        suite.expect(NotchDesign.allCases.map(\.rawValue) == ["boringNotch", "vorssaint"],
                     "design ids are stable (they are stored)")
        suite.expect(NotchDesign.sanitized(nil) == .boringNotch && NotchDesign.sanitized("x") == .boringNotch
                        && NotchDesign.sanitized("vorssaint") == .vorssaint,
                     "Boring Notch is the default design (SPEC §3D)")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchDesign] as? String == "boringNotch"
                        && Defaults.registeredDefaults[DefaultsKey.notchBoringTab] as? String == "home",
                     "a fresh island opens in Boring Notch's design, on its Home tab")
        let name = "com.vorssaint.tests.notch-design.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: name) {
            defer { defaults.removePersistentDomain(forName: name) }
            defaults.set("vorssaint", forKey: DefaultsKey.notchDesign)
            suite.expect(NotchDesign.current(defaults) == .vorssaint, "Vorssaint's island stays one click away")
        }
    }

    private static func metrics(_ suite: TestSuite) {
        typealias M = BoringNotchMetrics
        suite.expect(M.openSize == CGSize(width: 640, height: 190), "Boring Notch opens at 640 × 190")
        let closed = M.radii(height: 20)
        let open = M.radii(height: 400)
        suite.expect(closed.top == 6 && closed.bottom == 14 && open.top == 19 && open.bottom == 24,
                     "corners are Boring Notch's: 6 / 14 closed, 19 / 24 open")
        let middle = M.radii(height: (M.closedHeight + M.openHeight) / 2)
        suite.expect(middle.top > 6 && middle.top < 19 && middle.bottom > 14 && middle.bottom < 24,
                     "corners blend while the island grows, so the shape never jumps")
        suite.expect(M.openSpring.duration == 0.42 && M.openSpring.bounce == 0.2
                        && M.closeSpring.duration == 0.45 && M.closeSpring.bounce == 0,
                     "Boring Notch's springs: response 0.42 / damping 0.8 opening, 0.45 / 1.0 closing")
    }

    private static func outline(_ suite: TestSuite) {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 32)
        let path = BoringNotchMetrics.outline(in: rect, top: 6, bottom: 14)
        let box = path.boundingBoxOfPath
        suite.expect(abs(box.width - 200) < 0.01 && abs(box.height - 32) < 0.01,
                     "the outline spans its whole rect, flared top corners included")
        suite.expect(path.contains(CGPoint(x: 100, y: 16)), "the middle of the island is filled")
        suite.expect(!path.contains(CGPoint(x: 1, y: 30)) && !path.contains(CGPoint(x: 199, y: 30)),
                     "the bottom corners are rounded off below the flared top")
        let tiny = BoringNotchMetrics.outline(in: CGRect(x: 0, y: 0, width: 20, height: 4), top: 19, bottom: 24)
        suite.expect(tiny.boundingBoxOfPath.width <= 20.01 && tiny.boundingBoxOfPath.height <= 4.01,
                     "radii are capped so a small island never draws outside itself")
    }

    private static func hooks(_ suite: TestSuite) {
        func source(_ path: String) -> String { (try? String(contentsOfFile: path, encoding: .utf8)) ?? "" }
        let view = source("Sources/Vorssaint/UI/Notch/NotchView.swift")
        let service = source("Sources/Vorssaint/Services/Notch/NotchService.swift")
        let support = source("Sources/Vorssaint/Services/Notch/NotchSupport.swift")
        let design = source("Sources/Vorssaint/Mantel/BoringNotch/BoringNotchDesign.swift")
        suite.expect(view.contains("BoringNotchOpenView(service: service)")
                        && view.contains("BoringNotchMusicActivity(service: service)")
                        && view.contains("BoringNotchMetrics.outline(in: rect"),
                     "the design swaps the open page, the music strip and the outline inside Vorssaint's view")
        suite.expect(service.contains("if NotchDesign.isBoringNotch { return BoringNotchMetrics.openSize }")
                        && support.contains("BoringNotchMetrics.openSpring"),
                     "the open size and the springs come from Boring Notch's numbers")
        suite.expect(!service.contains("BoringNotchWindow") && !design.contains("NSPanel"),
                     "one island window: the design never brings Boring Notch's own (SPEC rule 4)")
        suite.expect(design.contains("AppFeature.notch.isAvailable && current() == .boringNotch"),
                     "without the island installed, nothing is drawn in either design")
    }
}
