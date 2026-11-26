import Cocoa
import IOKit.pwr_mgt

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var systemSleepAssertionID: IOPMAssertionID = 0
    var displaySleepAssertionID: IOPMAssertionID = 0

    var isActive = false
    var activeSince: Date?
    var hyperEngaged = false
    var hyperSince: Date?
    var guardTimer: Timer?
    var guardActivity: NSObjectProtocol?
    var stopReason: String?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "keepDisplayOn": true,
            "hyperMode": false,
            "hyperEngaged": false,
            "hyperMinBatteryPercent": 20,
            "hyperMaxHours": 12.0
        ])

        // A crash or kill while Hyper mode was on leaves lid sleep disabled: undo it.
        if defaults.bool(forKey: "hyperEngaged") {
            if HyperMode.setSleepDisabled(false) {
                defaults.set(false, forKey: "hyperEngaged")
                print("Recovered: lid sleep re-enabled after a previous run")
            } else {
                print("Failed to re-enable sleep after a previous run (sudo -n pmset -a disablesleep 0)")
            }
        }

        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkGuards()
        }

        // Get the system status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Ensure we have a button
        guard let button = statusItem.button else {
            print("ERROR: Could not create status bar button")
            return
        }

        // Configure the button with SF Symbol coffee cup icon
        button.image = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "Caffeine")
        button.image?.size = NSSize(width: 18, height: 18)

        // Add click handler to toggle on click
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Note: We don't assign menu to statusItem to allow custom click handling

        print("Caffeine started - click the cup icon to toggle")
    }

    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click - show a freshly built menu
            statusItem.menu = buildMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Left click - toggle sleep
            toggleSleep()
        }
    }

    func buildMenu() -> NSMenu {
        let defaults = UserDefaults.standard
        let menu = NSMenu()

        let status = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let displayItem = NSMenuItem(
            title: "Keep display on",
            action: #selector(toggleKeepDisplayOn),
            keyEquivalent: ""
        )
        displayItem.state = defaults.bool(forKey: "keepDisplayOn") ? .on : .off
        displayItem.target = self
        menu.addItem(displayItem)

        let hyperItem = NSMenuItem(
            title: "Hyper mode (awake with lid closed)",
            action: #selector(toggleHyperMode),
            keyEquivalent: ""
        )
        hyperItem.state = defaults.bool(forKey: "hyperMode") ? .on : .off
        hyperItem.target = self
        menu.addItem(hyperItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    func statusText() -> String {
        guard isActive else { return stopReason ?? "Off" }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let start = hyperEngaged ? (hyperSince ?? Date()) : (activeSince ?? Date())
        let time = formatter.string(from: start)
        return hyperEngaged ? "Hyper mode on since \(time)" : "On since \(time)"
    }

    @objc func toggleSleep() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    func activate() {
        let assertionReason = "Caffeine preventing sleep" as CFString
        let systemSleepResult = createAssertion(
            type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            reason: assertionReason,
            assertionID: &systemSleepAssertionID
        )

        guard systemSleepResult == kIOReturnSuccess else {
            print("Failed to enable system sleep prevention (IOKit error: \(systemSleepResult))")
            systemSleepAssertionID = 0
            return
        }

        if UserDefaults.standard.bool(forKey: "keepDisplayOn") {
            let displaySleepResult = createAssertion(
                type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                reason: assertionReason,
                assertionID: &displaySleepAssertionID
            )

            guard displaySleepResult == kIOReturnSuccess else {
                releaseAssertion(&systemSleepAssertionID)
                print("Failed to enable display sleep prevention (IOKit error: \(displaySleepResult))")
                displaySleepAssertionID = 0
                return
            }
        }

        isActive = true
        activeSince = Date()
        stopReason = nil
        ProcessInfo.processInfo.disableAutomaticTermination("Caffeine is preventing sleep")
        print("Sleep prevention enabled (systemAssertionID: \(systemSleepAssertionID), displayAssertionID: \(displaySleepAssertionID))")

        if UserDefaults.standard.bool(forKey: "hyperMode") {
            engageHyper()
        }

        updateIcon()
    }

    func deactivate(reason: String? = nil) {
        releaseAssertion(&systemSleepAssertionID)
        releaseAssertion(&displaySleepAssertionID)
        disengageHyper()
        ProcessInfo.processInfo.enableAutomaticTermination("Caffeine is preventing sleep")
        isActive = false
        activeSince = nil
        stopReason = reason
        updateIcon()
        if let reason {
            print("Sleep prevention disabled (\(reason))")
        } else {
            print("Sleep prevention disabled")
        }
    }

    @discardableResult
    func engageHyper() -> Bool {
        if !HyperMode.setSleepDisabled(true) {
            if !runHyperSetup() || !HyperMode.setSleepDisabled(true) {
                showAlert(
                    message: "Hyper mode could not be enabled",
                    informative: "Caffeine keeps your Mac awake with the lid open only."
                )
                UserDefaults.standard.set(false, forKey: "hyperMode")
                return false
            }
        }

        hyperEngaged = true
        UserDefaults.standard.set(true, forKey: "hyperEngaged")
        hyperSince = Date()
        print("Hyper mode engaged")

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkGuards()
        }
        // Common mode keeps firing while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        guardTimer = timer
        guardActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Caffeine Hyper mode guards"
        )

        checkGuards()
        return true
    }

    func disengageHyper() {
        guard hyperEngaged else { return }

        if HyperMode.setSleepDisabled(false) {
            UserDefaults.standard.set(false, forKey: "hyperEngaged")
        } else {
            print("Failed to re-enable sleep (sudo -n pmset -a disablesleep 0)")
        }

        guardTimer?.invalidate()
        guardTimer = nil
        if let activity = guardActivity {
            ProcessInfo.processInfo.endActivity(activity)
            guardActivity = nil
        }
        hyperEngaged = false
        hyperSince = nil
        print("Hyper mode disengaged")
    }

    func runHyperSetup() -> Bool {
        // Accessory app: otherwise the alert opens behind other windows.
        NSApp.activate(ignoringOtherApps: true)

        let defaults = UserDefaults.standard
        let minBattery = defaults.integer(forKey: "hyperMinBatteryPercent")
        let maxHours = String(format: "%g", defaults.double(forKey: "hyperMaxHours"))

        let alert = NSAlert()
        alert.messageText = "Enable Hyper mode?"
        alert.informativeText = """
        Hyper mode keeps your Mac awake with the lid closed, also on battery. A closed Mac in a bag gets warm and drains its battery. Caffeine turns Hyper mode off at \(minBattery)% battery, after \(maxHours) hours, or when the Mac runs hot.

        macOS asks for your administrator password once, so Caffeine can switch lid sleep off and on without a password.
        """
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        switch HyperMode.installSudoersRule() {
        case .installed:
            return true
        case .cancelled:
            return false
        case .failed(let message):
            showAlert(message: "Hyper mode setup failed", informative: message)
            return false
        }
    }

    func showAlert(message: String, informative: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informative
        alert.runModal()
    }

    func checkGuards() {
        guard hyperEngaged else { return }
        let defaults = UserDefaults.standard

        let thermal = ProcessInfo.processInfo.thermalState
        if thermal == .serious || thermal == .critical {
            tripGuard("Mac running hot", thermal: true)
            return
        }

        let minBattery = defaults.integer(forKey: "hyperMinBatteryPercent")
        if let battery = HyperMode.batteryStatus(), battery.onBattery, battery.percent <= minBattery {
            tripGuard("battery at \(battery.percent)%", thermal: false)
            return
        }

        let maxHours = defaults.double(forKey: "hyperMaxHours")
        if let hyperSince, Date().timeIntervalSince(hyperSince) >= maxHours * 3600 {
            tripGuard("\(String(format: "%g", maxHours)) hour limit reached", thermal: false)
        }
    }

    func tripGuard(_ reason: String, thermal: Bool) {
        // Read lid and power state before deactivating; then stop everything.
        let lidClosed = HyperMode.isLidClosed()
        let onBattery = HyperMode.batteryStatus()?.onBattery ?? false
        deactivate(reason: "Turned off: \(reason)")

        // A Mac in a bag should actually sleep: closed lid on battery, or overheating.
        // A closed lid on AC with an external display is a desk, leave it awake.
        if lidClosed && (onBattery || thermal) {
            HyperMode.run("/usr/bin/pmset", ["sleepnow"])
        }
    }

    @objc func toggleKeepDisplayOn() {
        let defaults = UserDefaults.standard
        let keepDisplayOn = !defaults.bool(forKey: "keepDisplayOn")
        defaults.set(keepDisplayOn, forKey: "keepDisplayOn")
        guard isActive else { return }

        if keepDisplayOn {
            let result = createAssertion(
                type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                reason: "Caffeine preventing sleep" as CFString,
                assertionID: &displaySleepAssertionID
            )
            if result != kIOReturnSuccess {
                print("Failed to enable display sleep prevention (IOKit error: \(result))")
                displaySleepAssertionID = 0
                defaults.set(false, forKey: "keepDisplayOn")
            }
        } else {
            releaseAssertion(&displaySleepAssertionID)
        }
    }

    @objc func toggleHyperMode() {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: "hyperMode") {
            defaults.set(false, forKey: "hyperMode")
            disengageHyper()
        } else {
            if !HyperMode.isSetUp && !runHyperSetup() {
                return
            }
            defaults.set(true, forKey: "hyperMode")
            if isActive {
                engageHyper()
            }
        }
        updateIcon()
    }

    func createAssertion(type: CFString, reason: CFString, assertionID: inout IOPMAssertionID) -> IOReturn {
        IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
    }

    func releaseAssertion(_ assertionID: inout IOPMAssertionID) {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    func updateIcon() {
        guard let button = statusItem.button else { return }

        let symbolName: String
        let description: String
        if hyperEngaged {
            symbolName = "bolt.fill"
            description = "Caffeine Hyper mode on"
        } else if isActive {
            symbolName = "cup.and.saucer.fill"
            description = "Caffeine on"
        } else {
            symbolName = "cup.and.saucer"
            description = "Caffeine off"
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        button.image?.size = NSSize(width: 18, height: 18)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Homebrew's `uninstall quit:` goes through here, so an upgrade never
        // leaves lid sleep disabled behind.
        if isActive {
            deactivate()
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// Create and run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
