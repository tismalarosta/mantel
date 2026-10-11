// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Adapted from DockDoor by Ethan Bills (github.com/ejbills/DockDoor, GPL-3.0),
// DockDoor/Utilities/ActiveAppIndicator/ (window, positioning, coordinator).

import AppKit
import SwiftUI

/// C11: a mark in Vorssaint's accent colour under the front app's Dock icon
/// (line), or under every running app's icon with the front one brighter
/// (dots). One click-through overlay the size of the Dock, redrawn when the
/// front app or the running apps change, and checked once a second for the
/// Dock moving, resizing or hiding while the extra is installed.
final class DockActiveIndicator {
    static let shared = DockActiveIndicator()

    fileprivate struct Mark: Identifiable, Equatable {
        let id: pid_t
        let rect: CGRect
        let isFront: Bool
    }

    fileprivate final class Model: ObservableObject {
        @Published var marks: [Mark] = []
        @Published var style: DockExtrasSupport.IndicatorStyle = .line
    }

    private let model = Model()
    private var panel: NSPanel?
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?

    private init() {}

    func syncWithPreferences() {
        if DockExtrasSupport.activeIndicatorOn, AXIsProcessTrusted() {
            start()
            refresh()
        } else {
            stop()
        }
    }

    private func start() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // The Dock rearranges a beat after an app launches or quits.
                self?.refresh()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.refresh() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() })
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
        model.marks = []
    }

    private func refresh() {
        guard DockExtrasSupport.activeIndicatorOn else { return stop() }
        let orientation = DockPreviewOrientation.sanitized(
            UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation"))
        let style = DockExtrasSupport.indicatorStyle(
            UserDefaults.standard.string(forKey: DefaultsKey.dockActiveIndicatorStyle))
        guard let dock = DockIcons.read(), Self.isOnScreen(dock.list) else {
            panel?.orderOut(nil)
            return
        }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let marks = dock.icons.compactMap { icon -> Mark? in
            guard style == .dots || icon.pid == front else { return nil }
            return Mark(id: icon.pid,
                        rect: DockExtrasSupport.indicatorRect(icon: icon.frame, dock: orientation, style: style),
                        isFront: icon.pid == front)
        }
        let area = marks.reduce(dock.list) { $0.union($1.rect) }.insetBy(dx: -4, dy: -4)
        let local = marks.map {
            Mark(id: $0.id, rect: $0.rect.offsetBy(dx: -area.minX, dy: -area.minY), isFront: $0.isFront)
        }
        if model.marks != local { model.marks = local }
        if model.style != style { model.style = style }
        let panel = ensurePanel()
        let frame = Self.appKitRect(area)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: IndicatorView(model: model))
        self.panel = panel
        return panel
    }

    /// A hidden Dock keeps its list just off the screen edge.
    private static func isOnScreen(_ list: CGRect) -> Bool {
        guard let primary = NSScreen.screens.first?.frame.height else { return false }
        return NSScreen.screens.contains {
            DockExtrasSupport.topLeftRect(fromAppKit: $0.frame, primaryScreenHeight: primary)
                .insetBy(dx: 1, dy: 1).contains(CGPoint(x: list.midX, y: list.midY))
        }
    }

    private static func appKitRect(_ rect: CGRect) -> CGRect {
        let primary = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primary - rect.maxY, width: rect.width, height: rect.height)
    }
}

/// Draws the marks; top-left coordinates inside the overlay.
private struct IndicatorView: View {
    @ObservedObject var model: DockActiveIndicator.Model

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(model.marks) { mark in
                shape(mark)
                    .frame(width: mark.rect.width, height: mark.rect.height)
                    .position(x: mark.rect.midX, y: mark.rect.midY)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.marks)
    }

    @ViewBuilder
    private func shape(_ mark: DockActiveIndicator.Mark) -> some View {
        let colour = Color.accentColor.opacity(mark.isFront || model.style == .line ? 1 : 0.45)
        if model.style == .line {
            Capsule().fill(colour)
        } else {
            Circle().fill(colour).overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
        }
    }
}

/// The Dock's app icons and their running apps, read through the Dock's
/// accessibility list like Vorssaint's Dock Click hit test. Top-left
/// coordinates.
enum DockIcons {
    struct Icon {
        let pid: pid_t
        let frame: CGRect
    }

    static func read() -> (list: CGRect, icons: [Icon])? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }
        let element = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard let children = array(element, kAXChildrenAttribute as String),
              let list = children.first(where: { string($0, kAXRoleAttribute as String) == "AXList" }),
              let listFrame = frame(of: list),
              let items = array(list, kAXChildrenAttribute as String) else { return nil }
        var byPath: [String: pid_t] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isTerminated {
            if let path = app.bundleURL?.standardizedFileURL.path { byPath[path] = app.processIdentifier }
        }
        let icons = items.compactMap { item -> Icon? in
            guard string(item, kAXSubroleAttribute as String) == "AXApplicationDockItem",
                  let url = url(item), let pid = byPath[url.standardizedFileURL.path],
                  let frame = frame(of: item) else { return nil }
            return Icon(pid: pid, frame: frame)
        }
        return (listFrame, icons)
    }

    static func listFrame() -> CGRect? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return nil }
        let element = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard let children = array(element, kAXChildrenAttribute as String),
              let list = children.first(where: { string($0, kAXRoleAttribute as String) == "AXList" })
        else { return nil }
        return frame(of: list)
    }

    private static func array(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func url(_ element: AXUIElement) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &value) == .success else { return nil }
        return value as? URL
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size,
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }
}
