import Foundation

enum AppDetector {
    /// Known Chromium PWA extension/shortcut ID for calendar.google.com
    static let googleCalendarShortcutID = "kjbdgfilnfhdoflbpgamdcdgpehopbep"

    /// Discovers all Google Calendar web app bundles on the current user's Mac.
    /// If `explicitPaths` are provided (via `--app` or saved config), validates and returns those.
    static func discoverApps(explicitPaths: [String] = []) -> [String] {
        let fm = FileManager.default
        if !explicitPaths.isEmpty {
            return explicitPaths
                .map { NSString(string: $0).expandingTildeInPath }
                .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
                .filter { fm.fileExists(atPath: $0) }
        }

        var seen = Set<String>()
        var results: [String] = []

        func consider(_ rawPath: String) {
            let clean = URL(fileURLWithPath: rawPath).standardizedFileURL.path
            guard clean.hasSuffix(".app"), !seen.contains(clean), fm.fileExists(atPath: clean) else { return }
            if isGoogleCalendarAppBundle(clean) {
                seen.insert(clean)
                results.append(clean)
            }
        }

        // 1. Inspect apps pinned directly in the user's macOS Dock
        if let dockDefaults = UserDefaults(suiteName: "com.apple.dock"),
           let persistentApps = dockDefaults.array(forKey: "persistent-apps") as? [[String: Any]] {
            for entry in persistentApps {
                if let tileData = entry["tile-data"] as? [String: Any],
                   let fileData = tileData["file-data"] as? [String: Any],
                   let urlStr = fileData["_CFURLString"] as? String,
                   let url = URL(string: urlStr),
                   url.isFileURL {
                    consider(url.path)
                }
            }
        }

        // 2. Scan ~/Applications (including Chrome/Brave/Edge/Chromium Apps.localized subfolders) & /Applications
        let homeApps = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        let searchRoots = [homeApps, "/Applications"]
        for root in searchRoots where fm.fileExists(atPath: root) {
            guard let topItems = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for item in topItems {
                let fullPath = (root as NSString).appendingPathComponent(item)
                if item.hasSuffix(".app") {
                    consider(fullPath)
                } else if root == homeApps {
                    // Check 1 level deeper inside ~/Applications (e.g. "Chrome Apps.localized")
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue,
                       let subItems = try? fm.contentsOfDirectory(atPath: fullPath) {
                        for sub in subItems where sub.hasSuffix(".app") {
                            consider((fullPath as NSString).appendingPathComponent(sub))
                        }
                    }
                }
            }
        }

        return results
    }

    static func isGoogleCalendarAppBundle(_ appPath: String) -> Bool {
        let infoPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOfFile: infoPath) as? [String: Any] else { return false }

        let bundleID = (plist["CFBundleIdentifier"] as? String) ?? ""
        // Never touch Apple's built-in Calendar.app (it already has a native dynamic icon)
        if bundleID == "com.apple.iCal" {
            return false
        }

        // 1. Chromium-based PWAs (Chrome, Brave, Edge, Vivaldi, Arc, Chromium)
        if let shortcutID = plist["CrAppModeShortcutID"] as? String,
           shortcutID == googleCalendarShortcutID {
            return true
        }
        if let shortcutURL = plist["CrAppModeShortcutURL"] as? String,
           shortcutURL.lowercased().contains("calendar.google.com") {
            return true
        }

        // 2. Safari "Add to Dock" Web Apps (macOS Sonoma 14+)
        if bundleID.hasPrefix("com.apple.Safari.WebApp") {
            if plistContainsGoogleCalendarURL(plist) {
                return true
            }
            let manifestPath = (appPath as NSString).appendingPathComponent("Contents/Resources/Manifest.json")
            if let manifestText = try? String(contentsOfFile: manifestPath, encoding: .utf8),
               manifestText.lowercased().contains("calendar.google.com") {
                return true
            }
        }

        // 3. Site-specific browser wrappers (Unite, Coherence, Fluid, WebCatalog) or exact bundle name
        if plistContainsGoogleCalendarURL(plist) {
            return true
        }

        let appFileName = (appPath as NSString).lastPathComponent.lowercased()
        let bundleName = ((plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? "").lowercased()
        if appFileName == "google calendar.app" || bundleName == "google calendar" {
            return true
        }

        return false
    }

    private static func plistContainsGoogleCalendarURL(_ value: Any) -> Bool {
        if let str = value as? String {
            return str.lowercased().contains("calendar.google.com")
        } else if let dict = value as? [String: Any] {
            return dict.values.contains { plistContainsGoogleCalendarURL($0) }
        } else if let arr = value as? [Any] {
            return arr.contains { plistContainsGoogleCalendarURL($0) }
        }
        return false
    }
}
