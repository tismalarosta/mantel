// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// The app ships as Mantel: its own identity, and the text people read
/// swapped from "Vorssaint" at build time (build.sh), whole words only, so
/// code names built on the word keep working.
enum MantelBrandingTests {
    static func run(_ suite: TestSuite) {
        let build = (try? String(contentsOfFile: "build.sh", encoding: .utf8)) ?? ""
        suite.expect(build.contains("APP_NAME=\"Mantel\"") && build.contains("EXECUTABLE=\"Mantel\"")
                        && build.contains("APP_BUNDLE_ID=\"app.mantel.dev\""),
                     "the Mantel build has its own name, process and id (ending in .dev: no Vorssaint updates)")
        let rule = "(?<![A-Za-z])Vorssaint(?![A-Za-z])"
        suite.expect(build.components(separatedBy: "s/\(rule)/Mantel/g").count == 3,
                     "the same whole-word swap brands the sources and the Info.plist")
        func swap(_ text: String) -> String {
            text.replacingOccurrences(of: rule, with: "Mantel", options: .regularExpression)
        }
        suite.expect(swap("Quit Vorssaint") == "Quit Mantel" && swap("Vorssaint’s island") == "Mantel’s island"
                        && swap("Sair do Vorssaint") == "Sair do Mantel",
                     "sentences name Mantel")
        suite.expect(swap("libVorssaintNowPlaying.dylib") == "libVorssaintNowPlaying.dylib"
                        && swap("VorssaintBuildCommit") == "VorssaintBuildCommit"
                        && swap("com.vorssaint.utils") == "com.vorssaint.utils",
                     "code names, keys and ids built on the word are left alone")
        let fan = (try? String(contentsOfFile: "Sources/Vorssaint/Services/FanControl/FanControlXPC.swift",
                               encoding: .utf8)) ?? ""
        suite.expect(fan.contains("static let appBundleID = \"app.mantel.dev\"")
                        && DockClickSupport.isOwnBundleIdentifier("app.mantel.dev"),
                     "Mantel's own helpers and Dock tap know its id")
    }
}
