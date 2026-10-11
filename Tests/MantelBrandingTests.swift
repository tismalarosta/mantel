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
            func source(_ path: String) -> String { (try? String(contentsOfFile: path, encoding: .utf8)) ?? "" }
        // Vorssaint's TRADEMARKS.md: a fork shares with its own icon, logo and signing identity.
        suite.expect(FileManager.default.fileExists(atPath: "Resources/MantelBrand/AppIcon-Default.png")
                        && FileManager.default.fileExists(atPath: "Resources/MantelBrand/logo.png")
                        && build.contains("BRAND_DIR=Resources/MantelBrand swift Tools/MakeIcon.swift")
                        && source("Tools/MakeIcon.swift").contains("environment[\"BRAND_DIR\"]"),
                     "Mantel builds draw their own icon and menu bar glyph")
        suite.expect(build.contains("LEGACY_IDENTITY=\"Mantel Signing\"")
                        && source("Tools/setup-signing.sh").contains("IDENTITY=\"${SIGNING_IDENTITY:-Vorssaint Utils Signing}\""),
                     "Mantel builds sign with their own local identity; Vorssaint's stays Vorssaint's")
        // Mantel stays off Vorssaint's servers.
        let mantelBuild = source("Sources/Vorssaint/Mantel/MantelBuild.swift")
        suite.expect(mantelBuild.contains("defaults.set(false, forKey: DefaultsKey.screenshotSharingEnabled)")
                        && mantelBuild.contains("defaults.set(false, forKey: DefaultsKey.recorderSharingEnabled)")
                        && source("Sources/Vorssaint/main.swift").contains("MantelBuild.applyAtLaunch()")
                        && source("Sources/Vorssaint/Services/QuickTools/ScreenshotShareService.swift").contains("!MantelBuild.isMantel")
                        && source("Sources/Vorssaint/Services/Recorder/RecordingShareService.swift").contains("!MantelBuild.isMantel")
                        && source("Sources/Vorssaint/UI/Settings/ScreenshotSettings.swift").contains("if !MantelBuild.isMantel { Section {")
                        && source("Sources/Vorssaint/UI/Settings/ScreenRecorderSettings.swift").contains("if !MantelBuild.isMantel { Section {"),
                     "share links (screenshots.vorssaint.com) are off and hidden in Mantel")
        suite.expect(source("Sources/Vorssaint/App/AppDelegate.swift").contains("NSWorkspace.shared.open(MantelBuild.issues)"),
                     "feedback opens Mantel's GitHub issues instead of Vorssaint's server")
    }
}
