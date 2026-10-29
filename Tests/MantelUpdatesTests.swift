// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// Mantel's update rules: which release tags count, the signer it trusts,
/// and the installer's safety steps.
enum MantelUpdatesTests {
    static func run(_ suite: TestSuite) {
        suite.expect(MantelUpdates.version(fromTag: "mantel-v1.1.0") == "1.1.0", "a Mantel tag names its version")
        suite.expect(MantelUpdates.version(fromTag: "v3.4.1") == nil, "a Vorssaint tag is not a Mantel release")
        suite.expect(MantelUpdates.version(fromTag: "mantel-v") == nil, "a tag with no version is skipped")
        suite.expect(UpdateServiceSupport.isNewer("1.1.0", than: "1.0.0"), "a higher Mantel version is an update")

        let requirement = MantelUpdates.requirement(leafCertificate: Data("cert".utf8))
        suite.expect(requirement == "identifier \"app.mantel.dev\" and certificate leaf = H\"cd1b5069963d9878f92f1cfbe77f8912cdd5b2ed\"",
                     "an update must carry Mantel's id and this copy's certificate")

        let script = MantelUpdates.installerScript(requirement: requirement)
        let order = ["note fail-copy", "note fail-version", "note fail-verify", "note fail-swap", "note ok"]
            .map { script.range(of: $0)?.lowerBound }
        suite.expect(!order.contains(nil) && order.compactMap { $0 } == order.compactMap { $0 }.sorted(),
                     "the installer checks the staged copy's version and signature before it touches the app")
        suite.expect(script.contains("codesign -v --deep --strict -R=\"$REQ\" \"$STAGE\""),
                     "the installer verifies the whole bundle against the pinned signer")
        suite.expect(script.contains("/bin/mv \"$BACKUP\" \"$APP\""),
                     "a failed swap puts the old app back")
    }
}
