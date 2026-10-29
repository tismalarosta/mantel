// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import CoreWLAN

/// A network's saved login, read from macOS's keychain and kept in memory
/// only: never written anywhere, never logged. Its own file so the rest of
/// Stay Online never touches a secret.
struct WiFiCredentials {
    /// Set for a school or work network (802.1X, like a campus network that
    /// asks for a username), nil for a home network.
    private let username: String?
    private let secret: String?

    /// An open network: nothing to send.
    static let open = WiFiCredentials(username: nil, secret: nil)

    /// What macOS saved for this network. Shows macOS's own access prompt the
    /// first time; after "Always Allow" the read is silent.
    static func saved(for ssid: String) -> WiFiCredentials? {
        guard let data = ssid.data(using: .utf8) else { return nil }
        for domain in [CWKeychainDomain.system, .user] {
            var found: NSString?
            if CWKeychainFindWiFiPassword(domain, data, &found) == errSecSuccess, let found {
                return WiFiCredentials(username: nil, secret: found as String)
            }
        }
        for domain in [CWKeychainDomain.user, .system] {
            var user: NSString?
            var found: NSString?
            if CWKeychainFindWiFiEAPUsernameAndPassword(domain, data, &user, &found) == errSecSuccess,
               let user {
                return WiFiCredentials(username: user as String, secret: found as String?)
            }
        }
        return nil
    }

    /// Joins with this login. A school network gets its username too, which
    /// answers it where macOS would wait on its login box.
    func join(_ network: CWNetwork, on interface: CWInterface) throws {
        if let username {
            try interface.associate(toEnterpriseNetwork: network, identity: nil,
                                    username: username, password: secret)
        } else {
            try interface.associate(to: network, password: secret)
        }
    }
}
