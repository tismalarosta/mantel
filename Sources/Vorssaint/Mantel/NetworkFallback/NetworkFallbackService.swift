// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import AppKit
import Combine
import CoreLocation
import CoreWLAN
import Network
import os

/// Stay Online: while the Mac runs shut (`LidClosedSession`), checks once a
/// minute and moves to the best network of the user's list in range, and
/// restarts Wi-Fi when the Mac has been offline too long so macOS rejoins a
/// known network or the iPhone hotspot. The rules are in
/// `NetworkFallbackSupport`, saved logins in `WiFiCredentials`; this is the
/// CoreWLAN and Location side.
final class NetworkFallbackService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = NetworkFallbackService()
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "mantel",
                                    category: "network-fallback")

    enum Status: Equatable {
        case off
        case noWiFi
        case waitingForSession
        case waitingForLid
        case wifiOff
        case on(String?)
        case onHotspot
        case offline(since: Date)
    }

    @Published private(set) var status = Status.off
    @Published private(set) var locationStatus = CLAuthorizationStatus.notDetermined
    /// The networks this Mac knows, for the Add menu; empty without Location.
    @Published private(set) var knownNetworks: [String] = []
    /// Networks "Allow login" found no saved password for (open or web sign-in).
    @Published private(set) var missingLogins: Set<String> = []

    private var installed = false
    private let location = CLLocationManager()
    private let pathMonitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "mantel.network-fallback", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var online = true
    private var offlineSince: Date?
    private var lastRestart: Date?
    private var failedJoins: [String: Date] = [:]
    /// Logins read this launch, kept in memory only.
    private var logins: [String: WiFiCredentials] = [:]
    private var checking = false

    private override init() {
        super.init()
        location.delegate = self
        locationStatus = location.authorizationStatus
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            DispatchQueue.main.async { self?.pathChanged(online: satisfied) }
        }
        pathMonitor.start(queue: queue)
    }

    // MARK: - Settings

    var priority: [String] {
        get { NetworkFallbackSupport.sanitizedPriority(
            UserDefaults.standard.stringArray(forKey: DefaultsKey.networkFallbackPriority) ?? []) }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(NetworkFallbackSupport.sanitizedPriority(newValue),
                                      forKey: DefaultsKey.networkFallbackPriority)
        }
    }

    /// Networks whose saved login Mantel read once with the lid open.
    var allowedLogins: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: DefaultsKey.networkFallbackAllowedPasswords) ?? [])
    }

    private var restartWhenStuck: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.networkFallbackRestartWiFi)
    }

    // MARK: - Lifecycle

    func syncWithPreferences() {
        let wanted = AppFeature.networkFallback.isAvailable
        guard wanted != installed else { return }
        installed = wanted
        if wanted {
            LidClosedSession.shared.retain()
            LidClosedSession.shared.$lidShut
                .combineLatest(KeepAwakeManager.shared.$isActive, KeepAwakeManager.shared.$clamshellActive)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.sessionChanged() }
                .store(in: &cancellables)
            refreshKnownNetworks()
        } else {
            cancellables.removeAll()
            LidClosedSession.shared.release()
            sessionChanged()
        }
    }

    private func sessionChanged() {
        timer?.invalidate()
        timer = nil
        guard installed else { status = .off; return }
        guard CWWiFiClient.shared().interface() != nil else { status = .noWiFi; return }
        guard LidClosedSession.shared.lidShut else {
            let awake = KeepAwakeManager.shared
            status = awake.isActive && awake.clamshellActive ? .waitingForLid : .waitingForSession
            return
        }
        let timer = Timer(timeInterval: NetworkFallbackSupport.checkInterval, repeats: true) { [weak self] _ in
            self?.check()
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        check()
    }

    private func pathChanged(online: Bool) {
        guard online != self.online else { return }
        self.online = online
        offlineSince = online ? nil : Date()
        if timer != nil { check() }
    }

    // MARK: - One check

    private func check() {
        guard !checking, timer != nil else { return }
        checking = true
        let priority = self.priority
        let online = self.online
        let canSeeNames = hasLocation
        queue.async { [weak self] in
            guard let interface = CWWiFiClient.shared().interface() else {
                DispatchQueue.main.async { self?.checking = false }
                return
            }
            var visible = Set<String>()
            var scanned: [String: CWNetwork] = [:]
            // Without Location the names come back nil: skip the scan's cost.
            if canSeeNames, interface.powerOn() {
                for network in (try? interface.scanForNetworks(withSSID: nil)) ?? [] {
                    guard let ssid = network.ssid else { continue }
                    visible.insert(ssid)
                    // Several access points share a name: keep the strongest.
                    if (scanned[ssid]?.rssiValue ?? .min) < network.rssiValue { scanned[ssid] = network }
                }
            }
            let snapshot = NetworkFallbackSupport.Snapshot(
                wifiPowered: interface.powerOn(), online: online,
                currentSSID: interface.ssid(), visibleSSIDs: visible)
            let onHotspot = Self.wifiAddress(interface.interfaceName)
                .map(NetworkFallbackSupport.isPersonalHotspotAddress) ?? false
            DispatchQueue.main.async {
                guard let self else { return }
                self.updateStatus(snapshot, onHotspot: onHotspot)
                var action = NetworkFallbackSupport.decide(
                    snapshot, priority: priority, failedJoins: self.failedJoins,
                    offlineSince: self.offlineSince, lastRestart: self.lastRestart, now: Date())
                if action == .restartWiFi, !self.restartWhenStuck { action = .none }
                self.perform(action, interface: interface, scanned: scanned)
            }
        }
    }

    private func updateStatus(_ snapshot: NetworkFallbackSupport.Snapshot, onHotspot: Bool) {
        guard timer != nil else { return }
        if !snapshot.wifiPowered { status = .wifiOff }
        else if !snapshot.online, let offlineSince { status = .offline(since: offlineSince) }
        else if onHotspot { status = .onHotspot }
        else { status = .on(snapshot.currentSSID) }
    }

    private func perform(_ action: NetworkFallbackSupport.Action, interface: CWInterface,
                         scanned: [String: CWNetwork]) {
        switch action {
        case .none:
            checking = false
        case .restartWiFi:
            lastRestart = Date()
            Self.log.info("offline too long, restarting Wi-Fi")
            queue.async { [weak self] in
                try? interface.setPower(false)
                Thread.sleep(forTimeInterval: 2)
                try? interface.setPower(true)
                DispatchQueue.main.async { self?.checking = false }
            }
        case .join(let ssid):
            let isOpen = scanned[ssid]?.supportsSecurity(.none) == true
            // The keychain is only read for a network whose login was allowed
            // with the lid open: a prompt now would wait for nobody.
            guard let network = scanned[ssid], isOpen || allowedLogins.contains(ssid) else {
                failedJoins[ssid] = Date()
                checking = false
                return
            }
            let cached = logins[ssid]
            queue.async { [weak self] in
                // If access was allowed once but not always, this waits on
                // macOS's prompt; `checking` keeps the next checks from piling up.
                let login = isOpen ? WiFiCredentials.open : cached ?? WiFiCredentials.saved(for: ssid)
                var joined = false
                if let login {
                    joined = (try? login.join(network, on: interface)) != nil
                }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.checking = false
                    if let login { self.logins[ssid] = login }
                    if joined {
                        Self.log.info("joined a network from the list")
                        self.failedJoins[ssid] = nil
                    } else {
                        self.failedJoins[ssid] = Date()
                    }
                }
            }
        }
    }

    // MARK: - Saved logins

    /// Reads the saved login once with the lid open, so macOS's prompt is
    /// answered (Always Allow) while someone is there to answer it.
    func allowLogin(for ssid: String) {
        queue.async { [weak self] in
            let login = WiFiCredentials.saved(for: ssid)
            DispatchQueue.main.async {
                guard let self else { return }
                guard let login else { self.missingLogins.insert(ssid); return }
                self.missingLogins.remove(ssid)
                self.logins[ssid] = login
                self.objectWillChange.send()
                var allowed = self.allowedLogins
                allowed.insert(ssid)
                UserDefaults.standard.set(Array(allowed).sorted(),
                                          forKey: DefaultsKey.networkFallbackAllowedPasswords)
            }
        }
    }

    // MARK: - Location

    var hasLocation: Bool {
        switch locationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return true
        default: return false
        }
    }

    func requestLocation() {
        if locationStatus == .notDetermined {
            location.requestWhenInUseAuthorization()
        } else if let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
        refreshKnownNetworks()
    }

    func refreshKnownNetworks() {
        guard installed else { return }
        queue.async { [weak self] in
            let profiles = CWWiFiClient.shared().interface()?.configuration()?.networkProfiles
            let names = (profiles?.array as? [CWNetworkProfile] ?? []).compactMap(\.ssid)
            DispatchQueue.main.async { self?.knownNetworks = names }
        }
    }

    func openWiFiSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Helpers

    private static func wifiAddress(_ name: String?) -> String? {
        guard let name else { return nil }
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = entry.pointee
            guard String(cString: ifa.ifa_name) == name, let address = ifa.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            return String(cString: host)
        }
        return nil
    }
}
