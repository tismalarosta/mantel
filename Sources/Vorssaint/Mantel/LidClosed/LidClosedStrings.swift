// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Matisse Lurie-Giner
// Part of Mantel, a fork of Vorssaint (github.com/vorssaint/vorssaint-utils).

import Foundation

/// Strings for Stay Online and Lid Pause. English only for now; every
/// language reads the English text until it is translated.
struct LidClosedFeatureStrings {
    let onlineTitle = "Stay online"
    let onlineHubDescription = "Keep the Mac on Wi-Fi or your iPhone's hotspot with the lid shut"
    let waitingSession = "Waiting: starts with a Keep Awake session in closed-lid mode."
    let waitingLid = "Waiting: runs only while the lid is shut, so it never switches networks under you."
    let runningOnFormat = "Running. On %@."
    let runningOnHotspot = "Running. On the iPhone hotspot; checks every minute for a network from the list."
    let runningOfflineFormat = "Running. Offline for %d s; Wi-Fi restarts at 90 s if nothing from the list shows up."
    let runningWifiOff = "Running. Wi-Fi is off, so nothing is switched."
    let noWiFi = "This Mac has no Wi-Fi."
    let location = "Location"
    let locationCaption = "macOS shows Wi-Fi names only to apps with Location access. Without it, Stay Online can only restart Wi-Fi when the Mac goes offline."
    let locationAllow = "Allow"
    let locationAllowed = "Allowed"
    let locationDenied = "Open Settings"
    let order = "Network order"
    let orderCaption = "Best first. Mantel joins the highest one in range and leaves a lower one, or the hotspot, when a better one appears. Drag to reorder."
    let orderEmpty = "No networks yet. Add the ones you use, best first."
    let add = "Add"
    let addCaption = "From the networks this Mac already knows."
    let loginAllowed = "Login allowed"
    let loginAllow = "Allow login"
    let loginMissing = "No saved login"
    let loginMissingHelp = "This Mac has no password saved for this network. An open network is joined without one. A network that signs you in on a web page (like ESSEC STUDENT) cannot be signed into with the lid shut: if it asks again, Mantel falls back to the hotspot."
    let loginNote = "\"Allow login\": macOS asks once for your Mac password so Mantel can read the saved Wi-Fi password, or the username and password of a school network like ESSEC. Click Always Allow. Needed because the lid will be shut when the switch happens."
    let remove = "Remove"
    let hotspot = "iPhone hotspot fallback"
    let hotspotCaption = "When no network from the list is in range, macOS joins your iPhone's hotspot on its own (Instant Hotspot). Mantel moves back to Wi-Fi as soon as one from the list returns."
    let hotspotHelp = "Needs System Settings, Wi-Fi, \"Ask to join hotspots\" set to Automatic, and the same Apple Account on the iPhone with Bluetooth on."
    let openWiFiSettings = "Open Wi-Fi Settings"
    let restart = "Restart Wi-Fi when stuck"
    let restartCaption = "Offline for 90 seconds with nothing from the list in range: Wi-Fi is turned off and on, at most every 5 minutes, so macOS rejoins what it can."

    let pauseTitle = "Pause apps with the lid closed"
    let pauseHubDescription = "Freeze every app except the ones you keep while the lid is shut"
    let pauseEverything = "Pause everything else"
    let pauseCaption = "While Keep Awake runs with the lid shut, every Dock app not listed below is frozen (no CPU, no network) and wakes up exactly where it was when you open the lid. Menu bar helpers and macOS itself are never touched."
    let keep = "Keep running"
    let keepCaption = "These apps, and every process they start (Chrome's helpers, Claude's node and claude processes, a terminal's shells), keep working."
    let keepAddCaption = "From the apps running now."
    let pausedNowFormat = "Paused now: %@."
    let wouldPauseFormat = "With the lid shut now, these would pause: %@."
    let nothingToPause = "Nothing would pause right now."
}

extension FeatureStrings {
    static func lidClosed(_ language: AppLanguage) -> LidClosedFeatureStrings {
        LidClosedFeatureStrings()
    }
}
