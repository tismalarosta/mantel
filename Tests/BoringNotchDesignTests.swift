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
        calendarPanel(suite)
        shelf(suite)
        tabs(suite)
        choices(suite)
    }

    /// Slice 5f: Vorssaint's pages as tabs in Boring Notch's frame.
    private static func tabs(_ suite: TestSuite) {
        typealias T = BoringNotchTabs
        suite.expect(Set(T.extras).isDisjoint(with: T.native) && !T.extras.contains(.captures)
                        && [.timer, .notifications, .downloads, .agents, .watch, .mixer, .clipboard, .scratchpad]
                            .allSatisfy(T.extras.contains),
                     "SPEC §3D's eight Vorssaint pages can be tabs; Home and Shelf cover the rest, captures stays Vorssaint's")
        suite.expect(T.parse("timer,bogus,music,tools") == [.timer, .tools] && T.parse("") == []
                        && T.stored([.tools, .timer]) == "timer,tools",
                     "hidden tabs are stored in a stable order and unknown or native names are dropped")
        let tabsSuite = "com.vorssaint.tests.notch-tabs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: tabsSuite)!
        defer { defaults.removePersistentDomain(forName: tabsSuite) }
        suite.expect(T.hidden(defaults) == [.system, .tools], "System and Tools start hidden, the eight pages shown")
        defaults.set("", forKey: DefaultsKey.notchBoringHiddenTabs)
        suite.expect(T.hidden(defaults).isEmpty, "an emptied list shows every page")
        suite.expect(T.visible(modules: [.controls, .watch, .music, .timer, .tools, .files], hidden: [.tools]) == [.watch, .timer],
                     "tabs follow the island's own section order, without hidden or native sections")
        suite.expect(T.page(selected: .music, storedTab: .shelf) == .shelf && T.page(selected: .controls, storedTab: .home) == .home
                        && T.page(selected: .files, storedTab: .home) == .shelf
                        && T.page(selected: .timer, storedTab: .shelf) == .module(.timer),
                     "the page follows Vorssaint's section, so its shortcuts and activities land on their tab")
        suite.expect(T.anchor(for: .home, modules: [.files, .timer, .controls]) == .controls
                        && T.anchor(for: .shelf, modules: [.music, .files]) == .files
                        && T.anchor(for: .home, modules: [.timer]) == nil,
                     "Home and Shelf select a section of their own, leaving a Vorssaint page behind")
        suite.expect(T.drawsOpenPage(showingSections: false, showingAppPanel: false, showingMetric: false, selected: .timer)
                        && !T.drawsOpenPage(showingSections: false, showingAppPanel: false, showingMetric: false, selected: .captures)
                        && !T.drawsOpenPage(showingSections: false, showingAppPanel: true, showingMetric: false, selected: .music)
                        && !T.drawsOpenPage(showingSections: false, showingAppPanel: false, showingMetric: true, selected: .system),
                     "the app panel, a metric's detail and captures keep Vorssaint's own page")
        let tall = CGSize(width: 440, height: 320)
        suite.expect(T.openSize(selected: .music, vorssaint: tall, mirrorIsBoringNotch: true) == BoringNotchMetrics.openSize
                        && T.openSize(selected: .camera, vorssaint: tall, mirrorIsBoringNotch: true) == BoringNotchMetrics.openSize
                        && T.openSize(selected: .timer, vorssaint: tall, mirrorIsBoringNotch: true) == CGSize(width: 640, height: 320)
                        && T.openSize(selected: .timer, vorssaint: CGSize(width: 440, height: 120), mirrorIsBoringNotch: true)
                            == BoringNotchMetrics.openSize,
                     "Home, Shelf and the mirror keep 640 × 190; a Vorssaint page only ever makes the notch taller")
        suite.expect(T.pageSize(island: CGSize(width: 640, height: 190), headerHeight: 32) == CGSize(width: 578, height: 146),
                     "a page gets the room inside Boring Notch's insets")
        let few = T.layout(count: 3, left: 190, right: 146)
        let many = T.layout(count: 11, left: 190, right: 146)
        suite.expect(few.width == 46 && few.leftCount == 3, "three tabs keep Boring Notch's width, all left of the camera")
        suite.expect(many.width >= T.minimumTabWidth && many.width < 46 && many.leftCount < 11
                        && CGFloat(many.leftCount) * many.width <= 190,
                     "many tabs narrow, then continue right of the camera")
        suite.expect(T.layout(count: 0, left: 100, right: 100).leftCount == 0, "no tabs, no row")
    }

    /// Slice 5f: gestures, mirror and lock screen pick-ones.
    private static func choices(_ suite: TestSuite) {
        suite.expect(BoringNotchGestureStyle.sanitized(nil) == .boringNotch && BoringNotchLockScreenStyle.sanitized("x") == .boringNotch
                        && BoringNotchMirrorShape.sanitized(nil) == .rectangle
                        && BoringNotchGestureSensitivity.sanitized(7) == .medium,
                     "Boring Notch wins the notch by default (SPEC rule 2), at its own default sensitivity")
        suite.expect(BoringNotchMirrorShape.circle.cornerRadius(side: 140) == 70
                        && BoringNotchMirrorShape.rectangle.cornerRadius(side: 140) == BoringNotchMetrics.openArtRadius
                        && !BoringNotchMirrorShape.vorssaint.isBoringNotch,
                     "the mirror is a rounded square or a circle, or Vorssaint's own preview")
        var tracker = BoringNotchGestureTracker()
        var fired: [BoringNotchGestureTracker.Action] = []
        for step in 0..<30 {
            if let action = tracker.handle(x: 0, y: 10, timestamp: Double(step) * 0.01, ended: false, allowVertical: true,
                                           expanded: false, sensitivity: 200, closes: true) { fired.append(action) }
        }
        suite.expect(fired == [.open], "a long pull down opens once, after 200 pt of travel")
        tracker = BoringNotchGestureTracker()
        var short: BoringNotchGestureTracker.Action?
        for step in 0..<10 {
            short = short ?? tracker.handle(x: 0, y: 10, timestamp: Double(step) * 0.01, ended: false, allowVertical: true,
                                            expanded: false, sensitivity: 200, closes: true)
        }
        suite.expect(short == nil, "a short pull does nothing")
        tracker = BoringNotchGestureTracker()
        var paused: BoringNotchGestureTracker.Action?
        for step in 0..<30 {
            paused = paused ?? tracker.handle(x: 0, y: 10, timestamp: Double(step) * 0.4, ended: false, allowVertical: true,
                                              expanded: false, sensitivity: 200, closes: true)
        }
        suite.expect(paused == nil, "travel split by pauses longer than 0.3 s never adds up")
        tracker = BoringNotchGestureTracker()
        var sideways: BoringNotchGestureTracker.Action?
        for step in 0..<40 {
            sideways = sideways ?? tracker.handle(x: 20, y: 10, timestamp: Double(step) * 0.01, ended: false, allowVertical: true,
                                                  expanded: false, sensitivity: 100, closes: true)
        }
        suite.expect(sideways == nil, "sideways travel never opens, and skips nothing (Boring Notch has no track swipe)")
        tracker = BoringNotchGestureTracker()
        var up: BoringNotchGestureTracker.Action?
        var upOff: BoringNotchGestureTracker.Action?
        var other = BoringNotchGestureTracker()
        for step in 0..<20 {
            up = up ?? tracker.handle(x: 0, y: -10, timestamp: Double(step) * 0.01, ended: false, allowVertical: true,
                                      expanded: true, sensitivity: 100, closes: true)
            upOff = upOff ?? other.handle(x: 0, y: -10, timestamp: Double(step) * 0.01, ended: false, allowVertical: true,
                                          expanded: true, sensitivity: 100, closes: false)
        }
        suite.expect(up == .close && upOff == nil, "a push up closes the open notch, unless the close gesture is off")
        func source(_ path: String) -> String { (try? String(contentsOfFile: path, encoding: .utf8)) ?? "" }
        let service = source("Sources/Vorssaint/Services/Notch/NotchService.swift")
        let lock = source("Sources/Vorssaint/Services/Notch/NotchLockScreenService.swift")
        let mirror = source("Sources/Vorssaint/Mantel/BoringNotch/BoringNotchMirrorView.swift")
        suite.expect(service.contains("if BoringNotchHooks.handlesGestures() {") && service.contains("NotchGestureSupport.isEnabled(), let panel"),
                     "Boring Notch's gestures ride on Vorssaint's own scroll handling and switch (one owner)")
        suite.expect(lock.contains("BoringNotchHooks.lockScreenIsBoring()") && lock.contains("BoringNotchLockScreenChoice("),
                     "the lock screen keeps Vorssaint's service and Space, only its parts change")
        suite.expect(mirror.contains("CameraPreviewService.shared") && !mirror.contains("AVCaptureSession()")
                        && !mirror.contains("AVCaptureDevice.requestAccess"),
                     "the mirror shows Vorssaint's camera session; it never opens the camera itself")
    }

    /// Slice 5e: Boring Notch's shelf menu on Vorssaint's shelf and tools.
    private static func shelf(_ suite: TestSuite) {
        typealias S = BoringNotchShelfSupport
        let photo = URL(fileURLWithPath: "/tmp/Photo.HEIC")
        let pdf = URL(fileURLWithPath: "/tmp/Report.pdf")
        suite.expect(S.isImage(photo) && S.isImage(URL(fileURLWithPath: "/a/b.png")) && !S.isImage(pdf),
                     "images are told apart by their type, whatever the case of the extension")
        suite.expect(S.outputName(for: photo, suffix: "no background", extension: "png") == "Photo no background.png"
                        && S.outputName(for: URL(fileURLWithPath: "/tmp/My File.jpeg"), suffix: nil, extension: "zip")
                            == "My File.zip",
                     "results are named after their source")
        let image = S.actions(fileURLs: [photo], hasOtherItems: false, mediaToolsAvailable: true)
        suite.expect(image == [.open, .openWith, .showInFinder, .share, .copyPath, .removeBackground, .convert,
                               .makePDF, .compress, .remove],
                     "an image gets Boring Notch's whole menu")
        let document = S.actions(fileURLs: [pdf], hasOtherItems: false, mediaToolsAvailable: true)
        suite.expect(!document.contains(.removeBackground) && !document.contains(.makePDF)
                        && document.contains(.compress),
                     "image actions only show for images")
        let noTools = S.actions(fileURLs: [photo], hasOtherItems: false, mediaToolsAvailable: false)
        suite.expect(!noTools.contains(.convert) && !noTools.contains(.compress) && noTools.contains(.removeBackground),
                     "convert and compress need Vorssaint's media tools installed; remove background is Mantel's own")
        let text = S.actions(fileURLs: [], hasOtherItems: true, mediaToolsAvailable: true)
        suite.expect(text == [.remove], "a note or link can only be removed")
        func source(_ path: String) -> String { (try? String(contentsOfFile: path, encoding: .utf8)) ?? "" }
        let view = source("Sources/Vorssaint/Mantel/BoringNotch/BoringNotchShelfView.swift")
        suite.expect(view.contains("ShelfService.shared") && view.contains("NotchFileToolsService.shared.openMedia(.imageCompressor")
                        && view.contains("NotchFileToolsService.shared.archive(")
                        && view.contains("ShelfSharePickerAnchor"),
                     "the shelf reuses Vorssaint's shelf, image tool, archive tool and share sheet")
    }

    /// Slice 5d: the calendar panel's days, events, reminders and panel order.
    private static func calendarPanel(_ suite: TestSuite) {
        typealias C = BoringNotchCalendarSupport
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 12))!
        let day = C.dayInterval(noon, calendar: calendar)
        suite.expect(day.duration == 86_400 && calendar.component(.hour, from: day.start) == 0,
                     "a day runs from midnight to midnight")
        let strip = C.stripDays(around: noon, calendar: calendar)
        suite.expect(strip.count == 29 && calendar.isDate(strip[14], inSameDayAs: noon),
                     "the day strip holds two weeks each side, today in the middle")
        func event(_ id: String, _ startHour: Int, _ endHour: Int, allDay: Bool = false, dayOffset: Int = 0)
            -> NotchCalendarEvent {
            let base = calendar.date(byAdding: .day, value: dayOffset, to: day.start)!
            return NotchCalendarEvent(id: id, title: id, calendar: "c",
                                      start: base.addingTimeInterval(Double(startHour) * 3600),
                                      end: base.addingTimeInterval(Double(endHour) * 3600),
                                      allDay: allDay, location: "")
        }
        let events = [event("late", 15, 16), event("early", 9, 10), event("holiday", 0, 24, allDay: true),
                      event("tomorrow", 9, 10, dayOffset: 1), event("overnight", -2, 1)]
        suite.expect(C.events(events, on: noon, calendar: calendar).map(\.id) == ["holiday", "overnight", "early", "late"],
                     "the panel shows the day's events, all-day first, then by start; other days left out")
        func reminder(_ id: String, _ hour: Int?, done: Bool) -> BoringNotchReminder {
            BoringNotchReminder(id: id, title: id, due: hour.map { day.start.addingTimeInterval(Double($0) * 3600) },
                                hasTime: hour != nil, completed: done, color: .fallback)
        }
        let list = [reminder("done", 8, done: true), reminder("later", 17, done: false),
                    reminder("soon", 9, done: false), reminder("someday", nil, done: false)]
        suite.expect(C.ordered(list, hidingCompleted: false).map(\.id) == ["soon", "later", "someday", "done"]
                        && C.ordered(list, hidingCompleted: true).map(\.id) == ["soon", "later", "someday"],
                     "open reminders first by due time; completed ones last, or hidden (Boring Notch's default)")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchBoringReminders] as? Bool == true
                        && Defaults.registeredDefaults[DefaultsKey.notchBoringHideCompleted] as? Bool == true,
                     "reminders show by default, completed ones hidden")
        let all: [BoringNotchSidePanel] = [.calendar, .upNext, .lyrics]
        suite.expect(C.panel(chosen: nil, available: all, isPlaying: false) == .calendar
                        && C.panel(chosen: nil, available: all, isPlaying: true) == .upNext,
                     "the calendar first while nothing plays, Up Next while music plays (Matisse, 2026-10-11)")
        suite.expect(C.panel(chosen: .lyrics, available: all, isPlaying: false) == .lyrics
                        && C.panel(chosen: .lyrics, available: [.calendar], isPlaying: true) == .calendar
                        && C.panel(chosen: nil, available: [], isPlaying: true) == nil,
                     "a choice made with the toggle wins while still offered")
        let plist = (try? String(contentsOfFile: "Resources/Info.plist", encoding: .utf8)) ?? ""
        suite.expect(plist.contains("NSRemindersFullAccessUsageDescription"),
                     "the app says why it asks for Reminders")
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
        suite.expect(service.contains("if NotchDesign.isBoringNotch { return .none }")
                        && service.contains("var mascotAtRest: Bool { mascotOn && idleContent == .none"),
                     "Boring Notch rests without Vorssaint's resting wings, and the companion can still rest there")
        let view = source("Sources/Vorssaint/UI/Notch/NotchView.swift")
        suite.expect(!view.contains("if NotchDesign.isBoringNotch { Color.clear.accessibilityHidden(true) }")
                        && service.contains("guard !NotchDesign.isBoringNotch else { return false }")
                        && service.components(separatedBy: "BoringNotchHooks.noticeSize(event: ").count >= 4,
                     "the companion: drawn in Boring Notch's closed notch, away while its full header is open, "
                        + "and never sent into Boring Notch's HUD, banner or sneak peek")
        let settings = source("Sources/Vorssaint/UI/Settings/NotchSettings.swift")
        suite.expect(settings.contains("NotchDesignStrings.localized(l10n.language).restingNote")
                        && source("Sources/Vorssaint/Mantel/BoringNotch/NotchDesignCard.swift")
                            .components(separatedBy: "restingNote: \"").count == 3,
                     "the resting picker says what Boring Notch's design does with it")
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
        suite.expect(service.contains("return BoringNotchHooks.openSize(selected: selected, vorssaint: size)")
                        && support.contains("BoringNotchMetrics.openSpring"),
                     "the open size and the springs come from Boring Notch's numbers")
        suite.expect(!service.contains("BoringNotchWindow") && !design.contains("NSPanel"),
                     "one island window: the design never brings Boring Notch's own (SPEC rule 4)")
        suite.expect(design.contains("AppFeature.notch.isAvailable && current() == .boringNotch"),
                     "without the island installed, nothing is drawn in either design")
    }
}
