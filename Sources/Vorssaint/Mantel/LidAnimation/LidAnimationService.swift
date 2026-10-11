// SPDX-License-Identifier: MIT AND GPL-3.0-or-later
// Adapted from Mac Duo's AppModel (github.com/DhananjayBhosale/MacDuo, commit f6862c8).
// Copyright (c) 2026 Mac Duo contributors, MIT License (see LICENSE-MacDuo.txt).
// Mantel changes: Copyright (C) 2026 Matisse Lurie-Giner, GPL-3.0-or-later.

import AppKit
import Carbon.HIToolbox
import IOKit.ps
import MetalKit
import OSLog
import ScreenCaptureKit

/// The overlay never takes focus from the app the user is in.
private final class LidOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The lid animation: the desktop follows the MacBook lid as it closes.
/// Mac Duo's controller, run as a Features hub switch. Kept from Mac Duo:
/// the sensor, the capture, the renderer, the motion model and every fail-open
/// rule (no reading for a second, a Space change, sleep or a display change
/// clears the desktop at once). Left to Vorssaint: settings, permissions,
/// login and the menu bar. Esc and the pause shortcut go through
/// `QuickToolHotkey`, the one Carbon hotkey owner, and a pause lasts until
/// the lid opens again instead of switching the feature off.
@MainActor
final class LidAnimationService: ObservableObject {
    static let shared = LidAnimationService()

    enum Status: Equatable {
        case off, unsupported, noMetal, checkingAccess, needsAccess
        case following, still, paused, testing, waitingForSensor, waitingForDisplay
        case captureFailed(String)
    }

    @Published private(set) var status: Status = .off
    @Published private(set) var pauseShortcutRegistrationFailed = false
    /// Nil until the sensor has been asked once.
    @Published private(set) var sensorAvailable: Bool?

    private struct Settings {
        var effect = FoldEffect.fallback
        var clearAngle = LidAnimationSupport.defaultClearAngle
        var clearWhenStill = true
        var stillnessDelay = LidAnimationSupport.defaultStillnessDelay
        var perspective = LidAnimationSupport.defaultPerspective
        var softness = LidAnimationSupport.defaultSoftness
        var shadow = LidAnimationSupport.defaultShadow

        static func current(_ defaults: UserDefaults = .standard) -> Settings {
            Settings(
                effect: FoldEffect.resolve(persisted: defaults.string(forKey: DefaultsKey.lidAnimationEffect)),
                clearAngle: LidAnimationSupport.sanitizedClearAngle(
                    defaults.double(forKey: DefaultsKey.lidAnimationClearAngle)),
                clearWhenStill: defaults.bool(forKey: DefaultsKey.lidAnimationClearWhenStill),
                stillnessDelay: LidAnimationSupport.sanitizedStillnessDelay(
                    defaults.double(forKey: DefaultsKey.lidAnimationStillnessDelay)),
                perspective: LidAnimationSupport.sanitizedUnit(
                    defaults.double(forKey: DefaultsKey.lidAnimationPerspective),
                    fallback: LidAnimationSupport.defaultPerspective),
                softness: LidAnimationSupport.sanitizedUnit(
                    defaults.double(forKey: DefaultsKey.lidAnimationSoftness),
                    fallback: LidAnimationSupport.defaultSoftness),
                shadow: LidAnimationSupport.sanitizedUnit(
                    defaults.double(forKey: DefaultsKey.lidAnimationShadow),
                    fallback: LidAnimationSupport.defaultShadow)
            )
        }
    }

    private let sensor = LidSensor()
    private let capture = DesktopCapture()
    private let device = MTLCreateSystemDefaultDevice()
    private let logger = Logger(subsystem: "mantel.lid-animation", category: "lifecycle")
    /// Far above every Vorssaint hotkey id, next to Type Clipboard's 2600.
    private let pauseHotkey = QuickToolHotkey(id: 2601)
    private let escapeHotkey = QuickToolHotkey(id: 2602)
    private static let escapeClaimKey = "mantelLidAnimationEscape"

    private var settings = Settings()
    private var renderer: FoldRenderer?
    private var panel: LidOverlayPanel?
    private var metalView: MTKView?
    private var timer: Timer?
    private var accessTask: Task<Void, Never>?
    private var notifications: [NSObjectProtocol] = []

    private var running = false
    private var accessGranted = false
    private var paused = false
    private var lastFailure: String?
    private var sessionActive = true
    private var systemAwake = true
    private var displayAwake = true
    private var lidAngle: Double?
    private var sensorAt: TimeInterval = 0
    private var waitingForSensor = false
    private var waitingForDisplay = false
    private var displayGeneration: UInt64 = 0
    private var stillness = LidStillness()
    private var liveAnimation = FoldVisualAnimation()
    private var motionReference = LidMotionReference()
    private var lidIsStill = false
    private var overlayVisible = false
    private var overlayRevealed = false
    private var powerCheckedAt: TimeInterval = -.infinity
    private var fps = 60
    private var testStart: TimeInterval?
    private var idleSince: TimeInterval?
    private var screenID: CGDirectDisplayID?
    private var reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    private init() {
        pauseHotkey.onPress = { [weak self] in
            MainActor.assumeIsolated { self?.pause(reason: "shortcut") }
        }
        escapeHotkey.onPress = { [weak self] in
            MainActor.assumeIsolated { self?.pause(reason: "Esc") }
        }
    }

    // MARK: Feature lifecycle

    func syncWithPreferences() {
        let wanted = AppFeature.lidAnimation.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.lidAnimationEnabled)
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.lidAnimationPauseShortcut,
                                            fallback: .lidAnimationPauseDefault)
        pauseShortcutRegistrationFailed = !pauseHotkey.sync(enabled: wanted, shortcut: shortcut,
                                                            storageKey: DefaultsKey.lidAnimationPauseShortcut)
        settings = .current()
        if wanted { start() } else { stop() }
    }

    func suspend() {
        pauseHotkey.unregister()
        stop()
    }

    /// Asks ScreenCaptureKit again, after the user granted Screen Recording.
    func recheckAccess() {
        guard running, !accessGranted else { return }
        verifyAccess()
    }

    /// Plays Mac Duo's eight-second scripted lid sweep on the real desktop.
    func testDesktop() {
        guard running else { return }
        guard accessGranted else { verifyAccess(); return }
        guard sensorAvailable == true else { return }
        paused = false
        lastFailure = nil
        testStart = ProcessInfo.processInfo.systemUptime
        refreshStatus()
        update()
    }

    private func start() {
        guard !running else { update(); return }
        guard device != nil else { publish(.noMetal); return }
        running = true
        sensor.onReading = { [weak self] angle in
            MainActor.assumeIsolated { self?.receive(angle) }
        }
        capture.onFirstFrame = { [weak self] in
            MainActor.assumeIsolated { self?.update() }
        }
        capture.onUnavailable = { [weak self] in
            MainActor.assumeIsolated { self?.hideOverlay() }
        }
        capture.onFailure = { [weak self] reason in
            MainActor.assumeIsolated { self?.captureStopped(reason) }
        }
        sensor.start()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        observeWorkspace()
        verifyAccess()
        logger.notice("Lid animation started.")
    }

    private func stop() {
        guard running else { publish(.off); return }
        running = false
        accessTask?.cancel()
        accessTask = nil
        testStart = nil
        paused = false
        lastFailure = nil
        hideOverlay()
        capture.stop()
        sensor.stop()
        timer?.invalidate()
        timer = nil
        for token in notifications {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            NotificationCenter.default.removeObserver(token)
        }
        notifications.removeAll()
        panel?.close()
        panel = nil
        renderer = nil
        metalView = nil
        screenID = nil
        lidAngle = nil
        resetStillness()
        publish(.off)
        logger.notice("Lid animation stopped.")
    }

    /// Ask the API actually used: a Core Graphics preflight can hold an old
    /// answer (Mac Duo's note), so ScreenCaptureKit is queried directly.
    private func verifyAccess() {
        accessTask?.cancel()
        publish(.checkingAccess)
        accessTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.capture.verifyAccess()
                guard !Task.isCancelled, self.running else { return }
                self.accessGranted = true
                self.refreshStatus()
                self.update()
            } catch {
                guard !Task.isCancelled, self.running else { return }
                self.accessGranted = false
                self.publish(.needsAccess)
                self.logger.error("Screen capture access failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: Sensor

    private func receive(_ angle: Double?) {
        guard running else { return }
        if angle == nil, sensorAvailable != true {
            // Never read once: this Mac has no lid angle sensor.
            sensorAvailable = false
            hideOverlay()
            capture.stop()
            refreshStatus()
            return
        }
        if angle != nil, sensorAvailable != true { sensorAvailable = true }
        let angleChanged = lidAngle != angle
        lidAngle = angle
        sensorAt = ProcessInfo.processInfo.systemUptime
        let settled = stillness.observe(angle: angle, at: sensorAt, delay: settings.stillnessDelay)
        motionReference.observe(angle: angle, isStill: settled, clearWhenStill: settings.clearWhenStill)
        var stateChanged = lidIsStill != settled
        lidIsStill = settled
        if paused, LidAnimationSupport.releasesPause(angle: angle, clearAngle: settings.clearAngle) {
            paused = false
            lastFailure = nil
            stateChanged = true
        }
        if angle == nil {
            hideOverlay()
            if capture.isRunning { capture.stop() }
        }
        if stateChanged { refreshStatus() }
        if angleChanged || stateChanged || waitingForSensor { update() }
    }

    // MARK: State

    private var liveReference: Double { motionReference.reference(clearAngle: settings.clearAngle) }
    private var fixedReference: Double { LidAnimationSupport.sanitizedClearAngle(settings.clearAngle) }
    private var clearedForStillness: Bool { settings.clearWhenStill && lidIsStill && testStart == nil }

    private var liveState: FoldVisualState {
        guard running, accessGranted, sessionActive, systemAwake, displayAwake,
              !waitingForSensor, !waitingForDisplay else { return .clear }
        if let start = testStart {
            let t = min(1, (ProcessInfo.processInfo.systemUptime - start) / LidAnimationSupport.testDuration)
            return .at(angle: LidAnimationSupport.testAngle(at: t, clearAngle: settings.clearAngle),
                       reference: fixedReference)
        }
        if paused || clearedForStillness { return .clear }
        guard let angle = lidAngle else { return .clear }
        return .at(angle: angle, reference: liveReference)
    }

    private func animatedState() -> FoldVisualState {
        let state = liveAnimation.sample(target: overlayVisible ? liveState : .clear,
                                         at: ProcessInfo.processInfo.systemUptime)
        if overlayVisible, overlayRevealed, let panel, panel.alphaValue != CGFloat(state.coverage) {
            panel.alphaValue = state.coverage
        }
        return state
    }

    private func uniforms() -> FoldUniforms {
        var u = FoldUniforms()
        let visual = liveState
        u.progress = Float(visual.progress)
        u.defocus = Float(visual.defocus)
        u.tilt = Float(visual.tilt)
        u.referenceAngle = Float(visual.referenceAngle)
        u.perspective = Float(settings.perspective)
        u.blur = Float(settings.softness)
        u.shadow = Float(settings.shadow)
        u.fadeOnly = reducedMotion ? 1 : 0
        u.effect = settings.effect.shaderIndex
        return u
    }

    private func refreshStatus() {
        guard running else { publish(.off); return }
        if sensorAvailable == false { publish(.unsupported); return }
        if !accessGranted {
            if status != .checkingAccess { publish(.needsAccess) }
            return
        }
        if testStart != nil { publish(.testing); return }
        if let lastFailure { publish(.captureFailed(lastFailure)); return }
        if paused { publish(.paused); return }
        if waitingForSensor { publish(.waitingForSensor); return }
        if waitingForDisplay { publish(.waitingForDisplay); return }
        publish(clearedForStillness ? .still : .following)
    }

    /// Published only on a real change: the sensor reports up to 120 times a
    /// second, and every assignment would redraw an open Settings page.
    private func publish(_ new: Status) {
        if status != new { status = new }
    }

    private func resetStillness() {
        stillness.reset()
        motionReference.reset()
        lidIsStill = false
    }

    // MARK: Pausing and failures

    private func pause(reason: String) {
        guard running else { return }
        logger.notice("Paused with \(reason, privacy: .public).")
        paused = true
        testStart = nil
        hideOverlay()
        capture.stop()
        refreshStatus()
    }

    /// A capture or render failure pauses like Esc, so a broken stream is
    /// not restarted in a loop; opening the lid tries again.
    private func fail(_ reason: String) {
        logger.error("Lid animation failed: \(reason, privacy: .public)")
        lastFailure = reason
        paused = true
        testStart = nil
        hideOverlay()
        capture.stop()
        refreshStatus()
    }

    private func captureStopped(_ reason: String) {
        let generation = displayGeneration
        hideOverlay()
        // ScreenCaptureKit can report the stream failure before AppKit posts
        // the matching display notification (Mac Duo's note). Decide after it.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.running, generation == self.displayGeneration else { return }
                if self.liveDisplay() == nil { self.suspendForDisplay() } else { self.fail(reason) }
            }
        }
    }

    // MARK: The loop

    private func updateFrameRate(at now: TimeInterval) {
        if now - powerCheckedAt >= 2 {
            powerCheckedAt = now
            let info = ProcessInfo.processInfo
            let externalPower: Bool
            if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
                externalPower = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
                    == kIOPSACPowerValue
            } else {
                externalPower = false
            }
            let rate = FoldFramePacing.rate(maximum: builtInScreen()?.maximumFramesPerSecond ?? 60,
                                            externalPower: externalPower,
                                            lowPower: info.isLowPowerModeEnabled,
                                            thermalPressure: info.thermalState == .serious
                                                || info.thermalState == .critical,
                                            moving: true)
            if fps != rate {
                fps = rate
                sensor.setPollingRate(rate)
            }
        }
        let rate = testStart != nil || !lidIsStill ? fps : min(60, fps)
        if metalView?.preferredFramesPerSecond != rate { metalView?.preferredFramesPerSecond = rate }
    }

    private func update() {
        let now = ProcessInfo.processInfo.systemUptime
        updateFrameRate(at: now)
        if !overlayVisible { liveAnimation.prime(at: now) }
        if let start = testStart, now - start > LidAnimationSupport.testDuration {
            testStart = nil
            refreshStatus()
        }
        guard running, accessGranted, sensorAvailable == true, sessionActive, systemAwake, displayAwake else { return }
        if now - sensorAt > 1 {
            // A delivery gap need not mean the device is gone. Fail open at
            // once and resume when fresh readings arrive.
            hideOverlay()
            if capture.isRunning { capture.stop() }
            if !waitingForSensor {
                waitingForSensor = true
                refreshStatus()
            }
            return
        }
        if waitingForSensor {
            waitingForSensor = false
            refreshStatus()
        }
        let shouldCapture = LidAnimationSupport.shouldCapture(angle: lidAngle,
                                                              reference: liveReference,
                                                              testing: testStart != nil,
                                                              paused: paused,
                                                              clearedForStillness: clearedForStillness)
        guard shouldCapture || capture.isRunning || overlayVisible || waitingForDisplay else { return }
        guard let display = liveDisplay() else { suspendForDisplay(); return }
        if waitingForDisplay {
            waitingForDisplay = false
            refreshStatus()
        }
        let target = liveState.progress
        if shouldCapture {
            idleSince = nil
            do { try prepareOverlay(on: display.screen) } catch { fail(error.localizedDescription); return }
            if !capture.isRunning {
                let width = Int(display.screen.frame.width * display.screen.backingScaleFactor)
                let height = Int(display.screen.frame.height * display.screen.backingScaleFactor)
                let generation = displayGeneration
                Task { [weak self] in
                    guard let self, generation == self.displayGeneration, self.running, self.accessGranted,
                          self.sessionActive, self.systemAwake, self.displayAwake, !self.paused,
                          !self.clearedForStillness, !self.waitingForDisplay,
                          ProcessInfo.processInfo.systemUptime - self.sensorAt <= 1 else { return }
                    do {
                        try await self.capture.start(displayID: display.id, width: width, height: height,
                                                     fps: min(60, self.fps))
                    } catch {
                        let reason = error.localizedDescription
                        DispatchQueue.main.async { [weak self] in
                            MainActor.assumeIsolated {
                                guard let self, self.running, generation == self.displayGeneration else { return }
                                if self.liveDisplay() == nil { self.suspendForDisplay() } else { self.fail(reason) }
                            }
                        }
                    }
                }
            }
        } else if capture.isRunning {
            if idleSince == nil { idleSince = now }
            if now - (idleSince ?? now) > 1.2 && !overlayVisible { capture.stop() }
        }
        if target > 0.0001, capture.frames.hasFrame, !overlayVisible {
            // A working way out comes before anything covers the desktop.
            guard registerEscape() else { fail("Esc could not be registered."); return }
            renderer?.resetProgress(to: 0)
            liveAnimation.reset()
            panel?.alphaValue = 0
            overlayRevealed = false
            overlayVisible = true
            panel?.orderFrontRegardless()
            // Let MTKView own its drawable: one paused explicit draw, then the
            // display-paced loop (Mac Duo's order).
            metalView?.isPaused = true
            metalView?.draw()
            metalView?.isPaused = false
        }
        if overlayVisible {
            let state = animatedState()
            if !capture.frames.hasFrame {
                hideOverlay()
            } else if target == 0 && state.isClear {
                panel?.alphaValue = 0
                hideOverlay()
            }
        }
        if clearedForStillness && !overlayVisible && capture.isRunning {
            capture.stop()
            idleSince = nil
        }
    }

    // MARK: Overlay

    private func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDisplayIsBuiltin(number.uint32Value) != 0 && CGDisplayIsActive(number.uint32Value) != 0
        }
    }

    private func liveDisplay() -> (screen: NSScreen, id: CGDirectDisplayID)? {
        guard let screen = builtInScreen(),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              CGDisplayIsInMirrorSet(number.uint32Value) == 0 else { return nil }
        return (screen, number.uint32Value)
    }

    private func suspendForDisplay() {
        hideOverlay()
        if capture.isRunning { capture.stop() }
        guard !waitingForDisplay else { return }
        waitingForDisplay = true
        refreshStatus()
    }

    private func prepareOverlay(on screen: NSScreen) throws {
        guard let device else { throw LidAnimationError.message("Metal is unavailable.") }
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw LidAnimationError.message("The built-in display is not available.")
        }
        let displayID = number.uint32Value
        if screenID != displayID || panel?.frame != screen.frame {
            hideOverlay()
            panel?.close()
            panel = nil
            renderer = nil
            metalView = nil
            capture.stop()
        }
        screenID = displayID
        guard panel == nil else { return }
        let panel = LidOverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                    backing: .buffered, defer: false, screen: screen)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.sharingType = .none
        panel.setFrame(screen.frame, display: false)
        let renderer = try FoldRenderer(device: device)
        renderer.frames = capture.frames
        renderer.parameters = { [weak self] in
            MainActor.assumeIsolated { self?.uniforms() ?? FoldUniforms() }
        }
        renderer.animatedState = { [weak self] in
            MainActor.assumeIsolated { self?.animatedState() }
        }
        renderer.onFailure = { [weak self] reason in
            MainActor.assumeIsolated { self?.fail(reason) }
        }
        renderer.onPresented = { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.running, self.overlayVisible, self.capture.frames.hasFrame else { return }
                // Reveal once the texture is ready; later completions never
                // undo the animated fade.
                if !self.overlayRevealed {
                    self.overlayRevealed = true
                    self.panel?.alphaValue = self.liveAnimation.value.coverage
                }
            }
        }
        let view = MTKView(frame: NSRect(origin: .zero, size: screen.frame.size), device: device)
        renderer.configure(view)
        view.isPaused = true
        panel.contentView = view
        self.panel = panel
        self.metalView = view
        self.renderer = renderer
    }

    private func hideOverlay() {
        panel?.orderOut(nil)
        panel?.alphaValue = 0
        metalView?.isPaused = true
        metalView?.releaseDrawables()
        overlayVisible = false
        overlayRevealed = false
        renderer?.releaseTransientResources()
        liveAnimation.reset()
        escapeHotkey.unregister()
    }

    private func registerEscape() -> Bool {
        escapeHotkey.sync(enabled: true,
                          shortcut: GlobalShortcut(keyCode: Int64(kVK_Escape), modifiers: []),
                          storageKey: Self.escapeClaimKey)
    }

    // MARK: System events

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        notifications.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                // Drop pixels from the previous Space; resume from a fresh frame.
                guard let self else { return }
                self.hideOverlay()
                self.capture.stop()
                self.update()
            }
        })
        let sleepEvents: [(Notification.Name, Int)] = [
            (NSWorkspace.willSleepNotification, 0), (NSWorkspace.screensDidSleepNotification, 1),
            (NSWorkspace.sessionDidResignActiveNotification, 2)]
        let wakeEvents: [(Notification.Name, Int)] = [
            (NSWorkspace.didWakeNotification, 0), (NSWorkspace.screensDidWakeNotification, 1),
            (NSWorkspace.sessionDidBecomeActiveNotification, 2)]
        for (name, kind) in sleepEvents {
            notifications.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if kind == 0 { self.systemAwake = false }
                    if kind == 1 { self.displayAwake = false }
                    if kind == 2 { self.sessionActive = false }
                    self.resetStillness()
                    self.hideOverlay()
                    self.capture.stop()
                    self.sensor.stop()
                }
            })
        }
        for (name, kind) in wakeEvents {
            notifications.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if kind == 0 { self.systemAwake = true }
                    if kind == 1 { self.displayAwake = true }
                    if kind == 2 { self.sessionActive = true }
                    // A display wake must not reactivate another user's session.
                    guard self.running, self.systemAwake, self.displayAwake, self.sessionActive else { return }
                    self.lidAngle = nil
                    self.sensorAt = ProcessInfo.processInfo.systemUptime
                    // The lid was closed to sleep, so the pause has done its job.
                    self.paused = false
                    self.lastFailure = nil
                    self.resetStillness()
                    self.refreshStatus()
                    self.sensor.start()
                }
            })
        }
        notifications.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.displayGeneration &+= 1
                self.capture.invalidateDisplayCache()
                self.hideOverlay()
                self.capture.stop()
                self.panel?.close()
                self.panel = nil
                self.screenID = nil
            }
        })
        notifications.append(center.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                                                object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        })
        // The settings page writes plain defaults; read them back on change.
        notifications.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let previousDelay = self.settings.stillnessDelay
                let previousAngle = self.settings.clearAngle
                self.settings = .current()
                if previousDelay != self.settings.stillnessDelay || previousAngle != self.settings.clearAngle {
                    self.resetStillness()
                }
            }
        })
    }
}
