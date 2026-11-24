import AppKit
import Darwin
import Foundation

let version = "1.0.0"
let launchAgentLabel = "io.github.vcdx71.not31"
let legacyLaunchAgentLabels = [
    "io.github.gcal-dock-icon.agent"
]

struct AppIconState: Codable, Equatable {
    let day: Int
    let appearance: String
}

struct PersistedState: Codable {
    var apps: [String: AppIconState]
}

struct UserConfig: Codable {
    var customAppPaths: [String]
}

final class Not31Manager {
    let fm = FileManager.default
    let homeDir: String
    let shareDir: String
    let binDir: String
    let installedBinaryPath: String
    let launchAgentsDir: String
    let plistPath: String
    let statePath: String
    let configPath: String

    init() {
        homeDir = fm.homeDirectoryForCurrentUser.path
        shareDir = "\(homeDir)/.local/share/not31"
        binDir = "\(homeDir)/.local/bin"
        installedBinaryPath = "\(binDir)/not31"
        launchAgentsDir = "\(homeDir)/Library/LaunchAgents"
        plistPath = "\(launchAgentsDir)/\(launchAgentLabel).plist"
        statePath = "\(shareDir)/state.json"
        configPath = "\(shareDir)/config.json"
    }

    func currentAppearanceName() -> String {
        let globalDomain = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
        let style = globalDomain?["AppleInterfaceStyle"] as? String
        return style == "Dark" ? "Dark" : "Light"
    }

    func loadConfig() -> UserConfig {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let cfg = try? JSONDecoder().decode(UserConfig.self, from: data) else {
            return UserConfig(customAppPaths: [])
        }
        return cfg
    }

    func saveConfig(_ config: UserConfig) throws {
        try fm.createDirectory(atPath: shareDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }

    func loadState() -> PersistedState {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: statePath)),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return PersistedState(apps: [:])
        }
        return state
    }

    func saveState(_ state: PersistedState) {
        try? fm.createDirectory(atPath: shareDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: URL(fileURLWithPath: statePath), options: .atomic)
        }
    }

    func targetApps(overridePaths: [String] = []) -> [String] {
        if !overridePaths.isEmpty {
            return AppDetector.discoverApps(explicitPaths: overridePaths)
        }
        let cfg = loadConfig()
        if !cfg.customAppPaths.isEmpty {
            return AppDetector.discoverApps(explicitPaths: cfg.customAppPaths)
        }
        return AppDetector.discoverApps()
    }

    /// Passes the transparent 1024x1024 glyph through a temporary .app bundle so macOS IconServices
    /// automatically applies the native OS appearance treatment (including Liquid Glass Light/Dark
    /// squircles on macOS 26+), while keeping the real PWA bundle's signature and cdhash untouched.
    func renderSystemStyledIcon(glyph: NSImage) throws -> NSImage {
        let uuid = UUID().uuidString
        let workDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("not31-icon-\(uuid)")
        let iconsetDir = (workDir as NSString).appendingPathComponent("app.iconset")
        let tempAppDir = (workDir as NSString).appendingPathComponent("TempRender.app")
        defer { try? fm.removeItem(atPath: workDir) }

        try fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: "\(tempAppDir)/Contents/Resources", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: "\(tempAppDir)/Contents/MacOS", withIntermediateDirectories: true)
        try fm.copyItem(atPath: "/usr/bin/true", toPath: "\(tempAppDir)/Contents/MacOS/TempRender")

        let sizes: [(String, Int)] = [
            ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
        ]

        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        for (name, px) in sizes {
            guard let ctx = CGContext(
                data: nil,
                width: px,
                height: px,
                bitsPerComponent: 8,
                bytesPerRow: px * 4,
                space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            ctx.interpolationQuality = .high
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            glyph.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
            NSGraphicsContext.restoreGraphicsState()
            if let cgImg = ctx.makeImage(),
               let png = NSBitmapImageRep(cgImage: cgImg).representation(using: .png, properties: [:]) {
                try png.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name)"))
            }
        }

        let iconutil = Process()
        iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        iconutil.arguments = ["-c", "icns", iconsetDir, "-o", "\(tempAppDir)/Contents/Resources/app.icns"]
        try iconutil.run()
        iconutil.waitUntilExit()

        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleIdentifier</key>
          <string>io.github.vcdx71.not31.render.\(uuid)</string>
          <key>CFBundleName</key>
          <string>TempRender</string>
          <key>CFBundleExecutable</key>
          <string>TempRender</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>CFBundleIconFile</key>
          <string>app.icns</string>
        </dict>
        </plist>
        """
        try infoPlist.write(toFile: "\(tempAppDir)/Contents/Info.plist", atomically: true, encoding: .utf8)

        let isIcon = NSWorkspace.shared.icon(forFile: tempAppDir)
        let finalImg = NSImage(size: NSSize(width: 512, height: 512))
        for px in [1024, 512, 256, 128, 64, 32] {
            guard let ctx = CGContext(
                data: nil,
                width: px,
                height: px,
                bitsPerComponent: 8,
                bytesPerRow: px * 4,
                space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            ctx.interpolationQuality = .high
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            isIcon.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
            NSGraphicsContext.restoreGraphicsState()
            if let cgImg = ctx.makeImage() {
                let rep = NSBitmapImageRep(cgImage: cgImg)
                if px == 1024 { rep.size = NSSize(width: 512, height: 512) }
                finalImg.addRepresentation(rep)
            }
        }
        return finalImg
    }

    func flushDockIconCacheAndReload(touchedApps: [String]) {
        var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
        let len = confstr(_CS_DARWIN_USER_CACHE_DIR, &buf, buf.count)
        if len > 0 {
            let cacheDir = String(cString: buf)
            if let entries = try? fm.contentsOfDirectory(atPath: cacheDir) {
                for entry in entries where entry.hasPrefix("com.apple.dock.iconcache") {
                    try? fm.removeItem(atPath: (cacheDir as NSString).appendingPathComponent(entry))
                }
            }
        }

        for appPath in touchedApps {
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: appPath)
            NSWorkspace.shared.noteFileSystemChanged(appPath)
        }

        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Dock"]
        try? killall.run()
        killall.waitUntilExit()
    }

    @discardableResult
    func updateIfNeeded(forcedDay: Int? = nil, force: Bool = false, overrideApps: [String] = []) -> Bool {
        let apps = targetApps(overridePaths: overrideApps)
        guard !apps.isEmpty else {
            log("No Google Calendar web app found. Install Google Calendar as a Chrome/Brave/Edge PWA or Safari Dock Web App, or pass --app /path/to/App.app.")
            return false
        }

        let targetDay = forcedDay ?? Calendar.current.component(.day, from: Date())
        guard (1...31).contains(targetDay) else {
            log("Invalid day \(targetDay) (expected 1...31)")
            return false
        }

        let desired = AppIconState(day: targetDay, appearance: currentAppearanceName())
        var persisted = loadState()

        let appsNeedingUpdate = apps.filter { appPath in
            if force { return true }
            let hasCustomIcon = fm.fileExists(atPath: "\(appPath)/Icon\r")
            return !hasCustomIcon || persisted.apps[appPath] != desired
        }

        guard !appsNeedingUpdate.isEmpty else {
            return false
        }

        do {
            let glyph = try CalendarIconRenderer.renderGlyph(day: targetDay)
            let styledIcon = try renderSystemStyledIcon(glyph: glyph)
            var updatedPaths: [String] = []

            for appPath in appsNeedingUpdate {
                if NSWorkspace.shared.setIcon(styledIcon, forFile: appPath, options: []) {
                    persisted.apps[appPath] = desired
                    updatedPaths.append(appPath)
                    log("Updated \(appPath) -> day \(targetDay) (\(desired.appearance))")
                } else {
                    log("Failed to set custom icon on \(appPath)")
                }
            }

            guard !updatedPaths.isEmpty else { return false }
            saveState(persisted)
            flushDockIconCacheAndReload(touchedApps: updatedPaths)
            return true
        } catch {
            log("Error rendering/applying icon: \(error.localizedDescription)")
            return false
        }
    }

    func resetIcons(overrideApps: [String] = []) {
        let persisted = loadState()
        let discovered = targetApps(overridePaths: overrideApps)
        let allKnown = Array(Set(discovered + Array(persisted.apps.keys))).filter { fm.fileExists(atPath: $0) }
        guard !allKnown.isEmpty else {
            print("No Google Calendar app bundles found to reset.")
            return
        }

        for appPath in allKnown {
            _ = NSWorkspace.shared.setIcon(nil, forFile: appPath, options: [])
            log("Restored default icon on \(appPath)")
        }
        try? fm.removeItem(atPath: statePath)
        flushDockIconCacheAndReload(touchedApps: allKnown)
    }

    func installService(customApps: [String] = []) -> Int32 {
        do {
            try fm.createDirectory(atPath: binDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: shareDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)

            if !customApps.isEmpty {
                let expanded = customApps
                    .map { NSString(string: $0).expandingTildeInPath }
                    .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
                for p in expanded where !fm.fileExists(atPath: p) {
                    fputs("Error: App bundle not found at \(p)\n", stderr)
                    return 1
                }
                try saveConfig(UserConfig(customAppPaths: expanded))
            }

            let apps = targetApps(overridePaths: customApps)
            if apps.isEmpty {
                fputs("""
                Warning: Could not auto-detect a Google Calendar web app yet.
                To create one:
                  • Chrome / Brave / Edge: Open https://calendar.google.com -> Menu -> Cast, save, and share -> Install Google Calendar...
                  • Safari: Open https://calendar.google.com -> File -> Add to Dock...
                Or specify a custom app path with: not31 install --app "/path/to/Google Calendar.app"

                """, stderr)
            }

            // Copy current executable into ~/.local/bin/not31 unless already executing from there
            let selfExec = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().standardizedFileURL.path
            let destExec = URL(fileURLWithPath: installedBinaryPath).standardizedFileURL.path
            if selfExec != destExec {
                if fm.fileExists(atPath: installedBinaryPath) {
                    try fm.removeItem(atPath: installedBinaryPath)
                }
                try fm.copyItem(atPath: selfExec, toPath: installedBinaryPath)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installedBinaryPath)
            }

            // Unload any legacy or existing LaunchAgents cleanly
            let uid = getuid()
            for label in legacyLaunchAgentLabels + [launchAgentLabel] {
                _ = runLaunchctl(["bootout", "gui/\(uid)/\(label)"])
                let oldPlist = "\(launchAgentsDir)/\(label).plist"
                if label != launchAgentLabel, fm.fileExists(atPath: oldPlist) {
                    try? fm.removeItem(atPath: oldPlist)
                }
            }
            // Clean up legacy gcal-dock-icon paths if present
            try? fm.removeItem(atPath: "\(binDir)/gcal-dock-icon")
            try? fm.removeItem(atPath: "\(homeDir)/.local/share/gcal-dock-icon")

            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>\(launchAgentLabel)</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(installedBinaryPath)</string>
                    <string>daemon</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>KeepAlive</key>
                <true/>
                <key>ProcessType</key>
                <string>Adaptive</string>
                <key>WorkingDirectory</key>
                <string>\(shareDir)</string>
                <key>StandardOutPath</key>
                <string>\(shareDir)/daemon.out.log</string>
                <key>StandardErrorPath</key>
                <string>\(shareDir)/daemon.err.log</string>
            </dict>
            </plist>
            """
            try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)

            // Apply today's icon synchronously first so the user sees immediate results
            if !apps.isEmpty {
                _ = updateIfNeeded(force: true, overrideApps: customApps)
            }

            let status = runLaunchctl(["bootstrap", "gui/\(uid)", plistPath])
            if status != 0 {
                fputs("Warning: launchctl bootstrap exited with code \(status)\n", stderr)
            }

            print("✓ Installed CLI to \(installedBinaryPath)")
            print("✓ Enabled LaunchAgent \(launchAgentLabel)")
            if !apps.isEmpty {
                for app in apps {
                    print("✓ Active on \(app)")
                }
            }
            return 0
        } catch {
            fputs("Installation failed: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    func uninstallService() -> Int32 {
        let uid = getuid()
        for label in legacyLaunchAgentLabels + [launchAgentLabel] {
            _ = runLaunchctl(["bootout", "gui/\(uid)/\(label)"])
            let p = "\(launchAgentsDir)/\(label).plist"
            try? fm.removeItem(atPath: p)
        }

        resetIcons()
        try? fm.removeItem(atPath: shareDir)

        let destExec = URL(fileURLWithPath: installedBinaryPath).standardizedFileURL.path
        if fm.fileExists(atPath: destExec) {
            try? fm.removeItem(atPath: destExec)
            print("✓ Removed \(installedBinaryPath)")
        }

        print("✓ Uninstalled LaunchAgent and restored default Google Calendar icon.")
        return 0
    }

    func printStatus() {
        let apps = targetApps()
        let persisted = loadState()
        let today = Calendar.current.component(.day, from: Date())
        let uid = getuid()
        let agentRunning = runLaunchctl(["print", "gui/\(uid)/\(launchAgentLabel)"]) == 0

        print("not31 v\(version)")
        print("  Today:          day \(today) (\(currentAppearanceName()) mode)")
        print("  LaunchAgent:    \(agentRunning ? "running (\(launchAgentLabel))" : "not loaded")")
        if apps.isEmpty {
            print("  Detected apps:  none")
        } else {
            print("  Detected apps:")
            for app in apps {
                let hasIcon = fm.fileExists(atPath: "\(app)/Icon\r")
                let st = persisted.apps[app].map { "day \($0.day) (\($0.appearance))" } ?? "untracked"
                print("    • \(app) [customIcon=\(hasIcon ? "yes" : "no"), state=\(st)]")
            }
        }
    }

    func runDaemon() -> Never {
        log("Starting not31 v\(version) daemon")
        _ = updateIfNeeded()

        var debounceItem: DispatchWorkItem?
        let scheduleCheck: (TimeInterval) -> Void = { [weak self] delay in
            debounceItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                _ = self?.updateIfNeeded()
            }
            debounceItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }

        // 1. Local midnight rollover
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { _ in
            scheduleCheck(0.5)
        }

        // 2. Wake from sleep (catches overnight sleep past midnight)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            scheduleCheck(2.0)
        }

        // 3. Timezone & system clock changes
        NotificationCenter.default.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { _ in
            NSTimeZone.resetSystemTimeZone()
            scheduleCheck(0.5)
        }
        NotificationCenter.default.addObserver(forName: .NSSystemClockDidChange, object: nil, queue: .main) { _ in
            scheduleCheck(0.5)
        }

        // 4. macOS Light / Dark mode change
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in
            scheduleCheck(1.0)
        }

        // 5. Watch parent folders of detected apps so browser PWA rebuilds get re-skinned automatically
        var fsSources: [DispatchSourceFileSystemObject] = []
        let parentDirs = Set(targetApps().map { ($0 as NSString).deletingLastPathComponent })
        for dir in parentDirs {
            let fd = open(dir, O_EVTONLY)
            if fd >= 0 {
                let src = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .rename, .attrib],
                    queue: .main
                )
                src.setEventHandler { scheduleCheck(1.5) }
                src.setCancelHandler { close(fd) }
                src.resume()
                fsSources.append(src)
            }
        }
        _ = fsSources

        // 6. Coalesced 60s safety heartbeat (pure in-memory/stat check; zero Dock reloads unless needed)
        let timer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            _ = self?.updateIfNeeded()
        }
        timer.tolerance = 15.0
        RunLoop.main.add(timer, forMode: .common)

        RunLoop.main.run()
        fatalError("Unreachable")
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = arguments
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus
    }

    private func log(_ msg: String) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        print("[\(fmt.string(from: Date()))] \(msg)")
        fflush(stdout)
    }
}

let manager = Not31Manager()
let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "status"

func parseCommonFlags(_ slice: ArraySlice<String>) -> (force: Bool, day: Int?, apps: [String], outDir: String?) {
    var force = false
    var day: Int?
    var apps: [String] = []
    var outDir: String?
    let arr = Array(slice)
    var i = 0
    while i < arr.count {
        switch arr[i] {
        case "--force", "-f":
            force = true
        case "--day" where i + 1 < arr.count:
            day = Int(arr[i + 1])
            force = true
            i += 1
        case "--app" where i + 1 < arr.count:
            apps.append(arr[i + 1])
            i += 1
        case "--out" where i + 1 < arr.count:
            outDir = arr[i + 1]
            i += 1
        default:
            break
        }
        i += 1
    }
    return (force, day, apps, outDir)
}

let flags = parseCommonFlags(args.dropFirst())

switch cmd {
case "install":
    exit(manager.installService(customApps: flags.apps))
case "uninstall":
    exit(manager.uninstallService())
case "update":
    _ = manager.updateIfNeeded(forcedDay: flags.day, force: flags.force, overrideApps: flags.apps)
case "reset":
    manager.resetIcons(overrideApps: flags.apps)
case "detect":
    let found = manager.targetApps(overridePaths: flags.apps)
    if found.isEmpty {
        print("No Google Calendar web apps detected.")
        exit(1)
    }
    for p in found { print(p) }
case "status":
    manager.printStatus()
case "daemon":
    manager.runDaemon()
case "export":
    let dir = NSString(string: flags.outDir ?? ".").expandingTildeInPath
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let days = flags.day.map { [$0] } ?? Array(1...31)
    for d in days {
        if let img = try? CalendarIconRenderer.renderGlyph(day: d),
           let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "\(dir)/calendar_\(d).png"))
        }
    }
    print("Exported \(days.count) icon(s) to \(dir)")
case "--version", "-v", "version":
    print("not31 \(version)")
default:
    print("""
    not31 v\(version) — Dynamic daily macOS Dock icon for Google Calendar Web Apps / PWAs

    Usage:
      not31 install [--app <path>]              Install CLI + background LaunchAgent
      not31 uninstall                           Remove LaunchAgent and restore default '31' icon
      not31 update [--force] [--day 1..31]      Update Dock icon now
      not31 reset [--app <path>]                Restore static '31' icon without uninstalling
      not31 status                              Show detected apps, current state, and daemon status
      not31 detect                              List auto-detected Google Calendar web apps
      not31 export [--day 1..31] [--out <dir>]  Export rendered 1024x1024 PNG icon(s)
    """)
}
