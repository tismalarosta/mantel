// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from Ice by Jordan Baird (github.com/jordanbaird/Ice, GPL-3.0):
// the expanding control item (MenuBar/ControlItem/ControlItem.swift), section
// nesting (MenuBar/MenuBarSection.swift), show on click / hover / scroll and
// smart rehide (Events/EventManager.swift), position seeding
// (Utilities/StatusItemDefaults.swift).

import AppKit
import ApplicationServices

/// Hides other apps' menu bar icons the way Ice does: a divider status item
/// left of Vorssaint's icon grows to 10,000 pt, pushing everything to its
/// left off the screen, and shrinks back to show them. Vorssaint's own icon
/// is the one control (SPEC §2): while this feature is on, its click shows
/// and hides, right-click opens the panel. Only Ice's macOS 26 safe parts are
/// here: no Ice Bar, layout editor, item search, spacing or tint, and no
/// private AppKit constraint for zero-width dividers.
final class MenuBarHiderService: ObservableObject {
    static let shared = MenuBarHiderService()

    @Published private(set) var isActive = false
    @Published private(set) var hiddenShown = false
    @Published private(set) var shortcutRegistrationFailed = false

    private struct Settings {
        var showOnClick = true
        var showOnHover = false
        var hoverDelay = MenuBarHiderSupport.defaultHoverDelay
        var showOnScroll = true
        var autoRehide = true
        var strategy = MenuBarRehideStrategy.fallback
        var rehideInterval = MenuBarHiderSupport.defaultRehideInterval
        var alwaysHiddenEnabled = false
        var shortcutsEnabled = false

        static func current(_ defaults: UserDefaults = .standard) -> Settings {
            Settings(
                showOnClick: defaults.bool(forKey: DefaultsKey.menuBarHiderShowOnClick),
                showOnHover: defaults.bool(forKey: DefaultsKey.menuBarHiderShowOnHover),
                hoverDelay: MenuBarHiderSupport.sanitizedHoverDelay(
                    defaults.double(forKey: DefaultsKey.menuBarHiderHoverDelay)),
                showOnScroll: defaults.bool(forKey: DefaultsKey.menuBarHiderShowOnScroll),
                autoRehide: defaults.bool(forKey: DefaultsKey.menuBarHiderAutoRehide),
                strategy: MenuBarRehideStrategy.sanitized(
                    defaults.string(forKey: DefaultsKey.menuBarHiderRehideStrategy)),
                rehideInterval: MenuBarHiderSupport.sanitizedRehideInterval(
                    defaults.double(forKey: DefaultsKey.menuBarHiderRehideInterval)),
                alwaysHiddenEnabled: defaults.bool(forKey: DefaultsKey.menuBarHiderAlwaysHiddenEnabled),
                shortcutsEnabled: defaults.bool(forKey: DefaultsKey.menuBarHiderShortcutsEnabled)
            )
        }
    }

    private var settings = Settings()
    private var hiddenDivider: NSStatusItem?
    private var alwaysHiddenDivider: NSStatusItem?
    private var alwaysHiddenShown = false
    private var shownByHover = false
    /// Far above every Vorssaint hotkey id, next to Mantel's 2600–2602.
    private let toggleHiddenHotkey = QuickToolHotkey(id: 2603)
    private let toggleAlwaysHiddenHotkey = QuickToolHotkey(id: 2604)
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var hoverWork: DispatchWorkItem?
    private var rehideWork: DispatchWorkItem?
    private var lastPointerCheck: TimeInterval = 0
    private var pointerWasInMenuBar = false
    private var appMenuCache: (pid: pid_t, frame: CGRect?, at: TimeInterval)?
    private var orderChecked = false

    /// Where Vorssaint's own icon is on screen; set by AppDelegate like the
    /// shelf's anchor. Nil while the icon is out of the bar.
    var mainIconFrameProvider: (() -> CGRect?)?

    private init() {
        toggleHiddenHotkey.onPress = { [weak self] in self?.toggleHidden() }
        toggleAlwaysHiddenHotkey.onPress = { [weak self] in self?.toggleAlwaysHidden() }
    }

    // MARK: Feature lifecycle

    func syncWithPreferences() {
        let wanted = AppFeature.menuBarHider.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.menuBarHiderEnabled)
        settings = .current()
        if wanted { activate() } else { deactivate() }
        let hidden = GlobalShortcut.saved(for: DefaultsKey.menuBarHiderToggleHiddenShortcut,
                                          fallback: .menuBarHiderToggleHiddenDefault)
        let alwaysHidden = GlobalShortcut.saved(for: DefaultsKey.menuBarHiderToggleAlwaysHiddenShortcut,
                                                fallback: .menuBarHiderToggleAlwaysHiddenDefault)
        let hiddenOK = toggleHiddenHotkey.sync(enabled: wanted && settings.shortcutsEnabled, shortcut: hidden,
                                               storageKey: DefaultsKey.menuBarHiderToggleHiddenShortcut)
        let alwaysOK = toggleAlwaysHiddenHotkey.sync(
            enabled: wanted && settings.shortcutsEnabled && settings.alwaysHiddenEnabled,
            shortcut: alwaysHidden, storageKey: DefaultsKey.menuBarHiderToggleAlwaysHiddenShortcut)
        shortcutRegistrationFailed = !(hiddenOK && alwaysOK)
    }

    func suspend() {
        toggleHiddenHotkey.unregister()
        toggleAlwaysHiddenHotkey.unregister()
        deactivate()
    }

    /// What a click on Vorssaint's own icon does right now. Called by
    /// `StatusItemController` before its usual left and right click.
    func mainIconAction(for event: NSEvent?) -> MenuBarMainIconAction {
        let flags = event?.modifierFlags ?? []
        return MenuBarHiderSupport.mainIconAction(
            hiderActive: isActive,
            rightClick: event?.type == .rightMouseUp || event?.type == .rightMouseDown,
            option: flags.contains(.option),
            control: flags.contains(.control),
            alwaysHiddenEnabled: settings.alwaysHiddenEnabled)
    }

    func toggleHidden() {
        guard isActive else { return }
        if hiddenShown { hideAll() } else { show(alwaysHidden: false, byHover: false) }
    }

    func toggleAlwaysHidden() {
        guard isActive, settings.alwaysHiddenEnabled else { return }
        if hiddenShown && alwaysHiddenShown { hideAll() } else { show(alwaysHidden: true, byHover: false) }
    }

    private func activate() {
        if alwaysHiddenDivider == nil, settings.alwaysHiddenEnabled {
            alwaysHiddenDivider = makeDivider(named: MenuBarHiderSupport.alwaysHiddenDividerName, alwaysHidden: true)
        } else if alwaysHiddenDivider != nil, !settings.alwaysHiddenEnabled {
            removeDivider(&alwaysHiddenDivider, named: MenuBarHiderSupport.alwaysHiddenDividerName)
            alwaysHiddenShown = false
        }
        if hiddenDivider == nil {
            hiddenDivider = makeDivider(named: MenuBarHiderSupport.hiddenDividerName, alwaysHidden: false)
        }
        if !isActive { isActive = true }
        installMonitors()
        applyLengths()
        if !orderChecked {
            // Frames settle a moment after the items are created.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.enforceOrder() }
        }
    }

    private func deactivate() {
        guard isActive || hiddenDivider != nil || alwaysHiddenDivider != nil else { return }
        removeMonitors()
        hoverWork?.cancel()
        rehideWork?.cancel()
        removeDivider(&alwaysHiddenDivider, named: MenuBarHiderSupport.alwaysHiddenDividerName)
        removeDivider(&hiddenDivider, named: MenuBarHiderSupport.hiddenDividerName)
        hiddenShown = false
        alwaysHiddenShown = false
        shownByHover = false
        orderChecked = false
        isActive = false
    }

    // MARK: Dividers

    /// A divider starts just left of Vorssaint's icon the first time, then
    /// keeps wherever the user ⌘-drags it (macOS saves the spot under its
    /// autosave name, as for Ice's `HItem`).
    private func makeDivider(named name: String, alwaysHidden: Bool) -> NSStatusItem {
        let defaults = UserDefaults.standard
        let key = StatusItemPlacementSupport.preferredPositionKey(for: name)
        if defaults.object(forKey: key) == nil {
            defaults.set(seedPosition(alwaysHidden: alwaysHidden), forKey: key)
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = name
        // Like Vorssaint's own icon: reorderable, never dragged off the bar.
        item.behavior = []
        item.isVisible = true
        if let button = item.button {
            button.target = self
            button.action = #selector(dividerClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = FeatureStrings.menuBarHider(L10n.shared.language).dividerHelp
        }
        return item
    }

    /// Just left of Vorssaint's icon as it sits on screen right now; the
    /// icon's saved position as a fallback (a fresh install may not have
    /// saved one yet), then Ice's own seeds.
    private func seedPosition(alwaysHidden: Bool) -> Double {
        let step = alwaysHidden ? 1.0 : 0.0
        if let icon = mainIconFrameProvider?(),
           let screen = NSScreen.screens.first(where: { $0.frame.intersects(icon) }) {
            return MenuBarHiderSupport.position(leftOf: icon.minX, screenMaxX: screen.frame.maxX) + step
        }
        let defaults = UserDefaults.standard
        let mainKey = StatusItemPlacementSupport.preferredPositionKey(
            for: StatusItemPlacementSupport.mainAutosaveName(in: defaults))
        let main = (defaults.object(forKey: mainKey) as? NSNumber)?.doubleValue
        return MenuBarHiderSupport.seedPosition(mainPosition: main, alwaysHidden: alwaysHidden)
    }

    /// Ice enforces its control items' order; here the divider has to stay
    /// left of Vorssaint's icon, or the icon would hide with the rest. A
    /// divider found on the wrong side is rebuilt once, just left of it.
    private func enforceOrder() {
        guard isActive, !orderChecked, let icon = mainIconFrameProvider?(),
              let window = hiddenDivider?.button?.window,
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(icon) }) else { return }
        orderChecked = true
        guard MenuBarHiderSupport.isMisplaced(divider: window.frame, rightNeighbour: icon) else { return }
        let defaults = UserDefaults.standard
        let name = MenuBarHiderSupport.hiddenDividerName
        let key = StatusItemPlacementSupport.preferredPositionKey(for: name)
        if let current = hiddenDivider { NSStatusBar.system.removeStatusItem(current) }
        hiddenDivider = nil
        defaults.set(MenuBarHiderSupport.position(leftOf: icon.minX, screenMaxX: screen.frame.maxX), forKey: key)
        hiddenDivider = makeDivider(named: name, alwaysHidden: false)
        if let always = alwaysHiddenDivider {
            NSStatusBar.system.removeStatusItem(always)
            alwaysHiddenDivider = nil
            let alwaysKey = StatusItemPlacementSupport.preferredPositionKey(
                for: MenuBarHiderSupport.alwaysHiddenDividerName)
            defaults.set(MenuBarHiderSupport.position(leftOf: icon.minX, screenMaxX: screen.frame.maxX) + 1,
                         forKey: alwaysKey)
            alwaysHiddenDivider = makeDivider(named: MenuBarHiderSupport.alwaysHiddenDividerName,
                                              alwaysHidden: true)
        }
        applyLengths()
    }

    /// Removing a status item deletes its saved position (Ice's note), so
    /// the spot is read first and written back.
    private func removeDivider(_ item: inout NSStatusItem?, named name: String) {
        guard let current = item else { return }
        let defaults = UserDefaults.standard
        let key = StatusItemPlacementSupport.preferredPositionKey(for: name)
        let saved = defaults.object(forKey: key)
        NSStatusBar.system.removeStatusItem(current)
        if let saved { defaults.set(saved, forKey: key) }
        item = nil
    }

    @objc private func dividerClicked(_ sender: NSStatusBarButton) {
        if let alwaysHiddenDivider, sender === alwaysHiddenDivider.button {
            toggleAlwaysHidden()
        } else {
            toggleHidden()
        }
    }

    private func applyLengths() {
        let lengths = MenuBarHiderSupport.dividerLengths(hiddenShown: hiddenShown,
                                                         alwaysHiddenShown: alwaysHiddenShown)
        configure(hiddenDivider, length: lengths.hidden, symbol: "chevron.left")
        configure(alwaysHiddenDivider, length: lengths.alwaysHidden, symbol: "chevron.compact.left")
    }

    private static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
        image?.isTemplate = true
        return image
    }

    private func configure(_ item: NSStatusItem?, length: CGFloat?, symbol: String) {
        guard let item, let button = item.button else { return }
        if let length {
            item.length = length
            // Ice: a disabled, unhighlighted cell, so the stretched item
            // never flashes when it expands.
            button.cell?.isEnabled = false
            button.isHighlighted = false
            button.image = nil
        } else {
            item.length = NSStatusItem.variableLength
            button.cell?.isEnabled = true
            button.image = Self.symbol(symbol)
        }
    }

    // MARK: Showing and hiding

    private func show(alwaysHidden: Bool, byHover: Bool) {
        hoverWork?.cancel()
        rehideWork?.cancel()
        hiddenShown = true
        if alwaysHidden, settings.alwaysHiddenEnabled { alwaysHiddenShown = true }
        shownByHover = byHover
        applyLengths()
        if settings.autoRehide, settings.strategy == .timed, !isInMenuBar(NSEvent.mouseLocation) {
            scheduleTimedRehide()
        }
    }

    private func hideAll() {
        hoverWork?.cancel()
        rehideWork?.cancel()
        guard hiddenShown || alwaysHiddenShown else { return }
        hiddenShown = false
        alwaysHiddenShown = false
        shownByHover = false
        applyLengths()
    }

    private func scheduleTimedRehide() {
        rehideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hideAll() }
        rehideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.rehideInterval, execute: work)
    }

    // MARK: Events

    /// Global monitors see other apps' events; the local twins catch clicks
    /// and scrolls on Mantel's own stretched divider, which covers the empty
    /// bar while icons are hidden (Ice's `UniversalEventMonitor`).
    private func installMonitors() {
        removeMonitors()
        var mask: NSEvent.EventTypeMask = []
        if settings.showOnClick || (settings.autoRehide && settings.strategy == .smart) { mask.insert(.leftMouseDown) }
        if settings.showOnHover || (settings.autoRehide && settings.strategy == .timed) { mask.insert(.mouseMoved) }
        if settings.showOnScroll { mask.insert(.scrollWheel) }
        if !mask.isEmpty {
            if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
                self?.handle(event)
            }) {
                monitors.append(global)
            }
            if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
                self?.handle(event)
                return event
            }) {
                monitors.append(local)
            }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            guard let self, self.settings.autoRehide, self.settings.strategy == .smart else { return }
            self.hideAll()
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.appMenuCache = nil
            guard self.settings.autoRehide, self.settings.strategy == .focusedApp,
                  self.hiddenShown, !self.isInMenuBar(NSEvent.mouseLocation) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.hideAll() }
        })
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        let workspace = NSWorkspace.shared.notificationCenter
        observers.forEach(workspace.removeObserver)
        observers.removeAll()
    }

    private func handle(_ event: NSEvent) {
        guard isActive else { return }
        switch event.type {
        case .leftMouseDown: handleClick(event)
        case .mouseMoved: handleMove()
        case .scrollWheel: handleScroll(event)
        default: break
        }
    }

    private func handleClick(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        if isInMenuBar(point) {
            guard settings.showOnClick, isEmptyMenuBarSpace(point) else { return }
            let option = event.modifierFlags.contains(.option)
            // Ice waits 50 ms so a click that opens something else lands first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                if option, self.settings.alwaysHiddenEnabled { self.toggleAlwaysHidden() } else { self.toggleHidden() }
            }
            return
        }
        guard settings.autoRehide, settings.strategy == .smart, hiddenShown else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + MenuBarHiderSupport.smartRehideDelay) { [weak self] in
            guard let self, self.hiddenShown, self.clickLandedInAppWindow(point) else { return }
            self.hideAll()
        }
    }

    private func handleMove() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPointerCheck > 1.0 / 30 else { return }
        lastPointerCheck = now
        let point = NSEvent.mouseLocation
        let inBar = isInMenuBar(point)
        defer { pointerWasInMenuBar = inBar }
        if settings.showOnHover {
            if !hiddenShown, inBar {
                if hoverWork == nil, isEmptyMenuBarSpace(point) {
                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }
                        self.hoverWork = nil
                        let current = NSEvent.mouseLocation
                        guard !self.hiddenShown, self.isEmptyMenuBarSpace(current) else { return }
                        self.show(alwaysHidden: false, byHover: true)
                    }
                    hoverWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + settings.hoverDelay, execute: work)
                }
            } else if !inBar {
                hoverWork?.cancel()
                hoverWork = nil
                // Shown by hovering, hidden by leaving (Ice).
                if shownByHover { hideAll() }
            }
        }
        if settings.autoRehide, settings.strategy == .timed, hiddenShown {
            if inBar {
                rehideWork?.cancel()
                rehideWork = nil
            } else if pointerWasInMenuBar || rehideWork == nil {
                scheduleTimedRehide()
            }
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard settings.showOnScroll, isInMenuBar(NSEvent.mouseLocation),
              let intent = MenuBarHiderSupport.scrollIntent(deltaX: Double(event.scrollingDeltaX),
                                                            deltaY: Double(event.scrollingDeltaY)) else { return }
        if intent { if !hiddenShown { show(alwaysHidden: false, byHover: false) } } else { hideAll() }
    }

    // MARK: Geometry (Cocoa coordinates, origin bottom-left of the main screen)

    private func menuBarRect(of screen: NSScreen) -> CGRect {
        var height = screen.frame.maxY - screen.visibleFrame.maxY
        if height <= 0 { height = NSStatusBar.system.thickness }
        // One extra point so the very top pixel row counts as the bar.
        return CGRect(x: screen.frame.minX, y: screen.frame.maxY - height,
                      width: screen.frame.width, height: height + 1)
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.insetBy(dx: 0, dy: -1).contains(point) }
    }

    private func isInMenuBar(_ point: CGPoint) -> Bool {
        guard let screen = screen(containing: point) else { return false }
        return menuBarRect(of: screen).contains(point)
    }

    /// Without Accessibility the app's menus cannot be told apart from
    /// empty space, so click and hover never fire (Ice requires it too).
    private func isEmptyMenuBarSpace(_ point: CGPoint) -> Bool {
        guard AXIsProcessTrusted(), let screen = screen(containing: point) else { return false }
        let bar = menuBarRect(of: screen)
        let notch = MenuBarHiderSupport.notchRect(screenFrame: screen.frame,
                                                  auxiliaryLeft: screen.auxiliaryTopLeftArea,
                                                  auxiliaryRight: screen.auxiliaryTopRightArea,
                                                  menuBarHeight: bar.height - 1)
        return MenuBarHiderSupport.isEmptyMenuBarSpace(point, menuBar: bar, appMenu: applicationMenuFrame(),
                                                       statusItems: statusItemFrames(), notch: notch)
    }

    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    private func cocoaRect(fromQuartz rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Every status item window on screen except Mantel's stretched
    /// dividers, which cover the empty bar on purpose.
    private func statusItemFrames() -> [CGRect] {
        let own = Set([hiddenDivider, alwaysHiddenDivider].compactMap { $0?.button?.window?.windowNumber })
        let level = Int(CGWindowLevelForKey(.statusWindow))
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return windows.compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == level,
                  let number = info[kCGWindowNumber as String] as? Int, !own.contains(number),
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return cocoaRect(fromQuartz: rect)
        }
    }

    /// The frontmost app's menus, read through Accessibility and cached for a
    /// second (and until the next app switch), as the pointer moves often.
    private func applicationMenuFrame() -> CGRect? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let now = ProcessInfo.processInfo.systemUptime
        if let cache = appMenuCache, cache.pid == pid, now - cache.at < 1 { return cache.frame }
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.2)
        var frame: CGRect?
        var menuBar: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXMenuBarAttribute as CFString, &menuBar) == .success,
           let menuBar, CFGetTypeID(menuBar) == AXUIElementGetTypeID() {
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString,
                                             &children) == .success,
               let items = children as? [AXUIElement] {
                for item in items {
                    guard let rect = Self.frame(of: item) else { continue }
                    frame = frame.map { $0.union(rect) } ?? rect
                }
            }
        }
        let converted = frame.map(cocoaRect(fromQuartz:))
        appMenuCache = (pid, converted, now)
        return converted
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size), size.width > 0 else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Ice's smart rule: a click counts when it lands on an ordinary window of
    /// a regular app. Menus, popovers, the Dock and the desktop do not, so
    /// using a shown icon's menu never hides it.
    private func clickLandedInAppWindow(_ point: CGPoint) -> Bool {
        let quartz = CGPoint(x: point.x, y: primaryHeight - point.y)
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return false }
        for info in windows {
            guard let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds), rect.contains(quartz) else { continue }
            guard info[kCGWindowLayer as String] as? Int == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let app = NSRunningApplication(processIdentifier: pid) else { return false }
            return app.activationPolicy == .regular && app.bundleIdentifier != "com.apple.dock"
        }
        return false
    }
}
