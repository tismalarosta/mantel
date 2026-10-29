// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).
// Installer after Vorssaint's UpdateInstallerSupport.installerScript().

import AppKit
import SwiftUI
import CryptoKit
import Security

/// Mantel's updates on Vorssaint's UpdateService: Mantel's own GitHub
/// releases (tag `mantel-v<version>`, asset `Mantel.zip`). By default an
/// update only opens its release page. "Install updates for me" downloads
/// the zip and swaps the app, accepting only a bundle signed with the same
/// certificate as the running copy (Mantel is self-signed, so Vorssaint's
/// Developer ID and Gatekeeper checks cannot apply).
enum MantelUpdates {
    static let repository = "tismalarosta/mantel"
    static let tagPrefix = "mantel-v"
    static let assetName = "Mantel.zip"
    static let installsForMeKey = "mantelUpdatesInstallForMe"
    /// Testing aid: `defaults write app.mantel.dev mantelVersionOverride 1.0.0`
    /// makes a newer release (one whose zip carries MantelVersion) look new.
    static let versionOverrideKey = "mantelVersionOverride"

    static var version: String {
        UserDefaults.standard.string(forKey: versionOverrideKey)
            ?? Bundle.main.object(forInfoDictionaryKey: "MantelVersion") as? String
            ?? "0"
    }

    /// The version a release tag names, or nil for a tag that is not Mantel's.
    static func version(fromTag tag: String) -> String? {
        guard tag.hasPrefix(tagPrefix) else { return nil }
        let version = String(tag.dropFirst(tagPrefix.count))
        return version.isEmpty ? nil : version
    }

    static var installsForMe: Bool { UserDefaults.standard.bool(forKey: installsForMeKey) }

    static func releasePage(version: String) -> URL {
        MantelBuild.repository.appendingPathComponent("releases/tag/\(tagPrefix)\(version)")
    }

    static func openReleasePage(version: String) { NSWorkspace.shared.open(releasePage(version: version)) }

    /// The code requirement an update must meet: Mantel's identifier, signed
    /// by the certificate that signed this copy. Nil for an ad-hoc signed
    /// copy, which then only gets the release page.
    static func signerRequirement(appPath: String = Bundle.main.bundlePath) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: appPath) as CFURL, [], &code) == errSecSuccess,
              let code else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let certificates = (info as? [String: Any])?[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first else { return nil }
        return requirement(leafCertificate: SecCertificateCopyData(leaf) as Data)
    }

    static func requirement(leafCertificate: Data) -> String {
        let hash = Insecure.SHA1.hash(data: leafCertificate).map { String(format: "%02x", $0) }.joined()
        return "identifier \"\(MantelBuild.bundleIdentifier)\" and certificate leaf = H\"\(hash)\""
    }

    /// Same arguments and result markers as Vorssaint's installer, so
    /// UpdateService launches it and reports its failures unchanged:
    /// $1 app path, $2 zip path, $3 pid to wait for, $4 result marker path,
    /// $5 uid (unused: Mantel never installs as root), $6 expected version.
    static func installerScript(requirement: String) -> String {
        """
        #!/bin/sh
        APP="$1"; ZIP="$2"; PID="$3"; RESULT="$4"; EXPECTED_VERSION="$6"
        SCRIPT="$0"
        REQ=\(UpdateInstallerSupport.shellSingleQuoted(requirement))
        WORK=""
        note() { /bin/echo "$1" > "$RESULT.progress" 2>/dev/null; }
        finish() {
            /bin/mv -f "$RESULT.progress" "$RESULT" 2>/dev/null
            [ -n "$WORK" ] && /bin/rm -rf "$WORK"
            /bin/rm -f "$ZIP"
            /usr/bin/open "$APP"
            case "$SCRIPT" in /*) /bin/rm -f "$SCRIPT";; esac
            exit 0
        }
        while kill -0 "$PID" 2>/dev/null; do sleep 0.3; done
        note fail-tempdir
        WORK="$(/usr/bin/mktemp -d)" || finish
        note fail-unzip
        /usr/bin/ditto -x -k "$ZIP" "$WORK" || finish
        note fail-no-app-in-zip
        SRC="$(/usr/bin/find "$WORK" -maxdepth 2 -name '*.app' -print -quit)"
        [ -n "$SRC" ] || finish
        note fail-copy
        DIR="$(/usr/bin/dirname "$APP")"
        STAGE="$DIR/.$(/usr/bin/basename "$APP").update-new"
        BACKUP="$APP.update-old.$PID"
        /bin/rm -rf "$STAGE"
        /usr/bin/ditto "$SRC" "$STAGE" || { /bin/rm -rf "$STAGE"; finish; }
        # The checks run on the staged copy: the exact bytes that get swapped in.
        /usr/bin/xattr -cr "$STAGE" 2>/dev/null
        note fail-version
        VERSION="$(/usr/libexec/PlistBuddy -c 'Print MantelVersion' "$STAGE/Contents/Info.plist" 2>/dev/null)"
        [ "$VERSION" = "$EXPECTED_VERSION" ] || { /bin/rm -rf "$STAGE"; finish; }
        note fail-verify
        /usr/bin/codesign -v --deep --strict -R="$REQ" "$STAGE" 2>/dev/null || { /bin/rm -rf "$STAGE"; finish; }
        note fail-swap
        if /bin/mv "$APP" "$BACKUP" && /bin/mv "$STAGE" "$APP"; then
            note ok
            /bin/rm -rf "$BACKUP"
        else
            [ -d "$BACKUP" ] && [ ! -d "$APP" ] && /bin/mv "$BACKUP" "$APP"
            /bin/rm -rf "$STAGE"
        fi
        finish
        """
    }
}

/// The Settings switch for installing updates, under Vorssaint's update toggles.
struct MantelUpdatesToggle: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(MantelUpdates.installsForMeKey) private var installsForMe = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(MantelUpdateStrings.localized(l10n.language).toggle, isOn: $installsForMe)
                .disabled(MantelUpdates.signerRequirement() == nil)
            // Vorssaint's SettingsCaptionText is private to SettingsView.swift.
            Text(MantelUpdateStrings.localized(l10n.language).caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MantelUpdateStrings {
    let toggle: String
    let caption: String

    static func localized(_ language: AppLanguage) -> MantelUpdateStrings {
        switch language {
        case .fr:
            return MantelUpdateStrings(
                toggle: "Installer les mises à jour pour moi",
                caption: "Désactivé : une nouvelle version ouvre sa page de téléchargement. Activé : Mantel la télécharge, vérifie qu'elle est signée comme cette copie, la remplace et redémarre.")
        default:
            return MantelUpdateStrings(
                toggle: "Install updates for me",
                caption: "Off: a new version opens its download page. On: Mantel downloads it, checks it is signed like this copy, swaps it in and restarts.")
        }
    }
}
