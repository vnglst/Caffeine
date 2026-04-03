import Cocoa
import IOKit.pwr_mgt

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isPreventingSleep = false
    var systemSleepAssertionID: IOPMAssertionID = 0
    var displaySleepAssertionID: IOPMAssertionID = 0
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
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
            // Right click - show menu
            let menu = NSMenu()
            let quitItem = NSMenuItem(
                title: "Quit",
                action: #selector(quit),
                keyEquivalent: "q"
            )
            quitItem.target = self
            menu.addItem(quitItem)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Left click - toggle sleep
            toggleSleep()
        }
    }
    
    @objc func toggleSleep() {
        isPreventingSleep.toggle()
        
        if isPreventingSleep {
            let assertionReason = "Caffeine preventing sleep" as CFString
            let systemSleepResult = createAssertion(
                type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                reason: assertionReason,
                assertionID: &systemSleepAssertionID
            )
            
            guard systemSleepResult == kIOReturnSuccess else {
                print("Failed to enable system sleep prevention (IOKit error: \(systemSleepResult))")
                isPreventingSleep = false
                return
            }

            let displaySleepResult = createAssertion(
                type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                reason: assertionReason,
                assertionID: &displaySleepAssertionID
            )
            
            if displaySleepResult == kIOReturnSuccess {
                print("Sleep prevention enabled (systemAssertionID: \(systemSleepAssertionID), displayAssertionID: \(displaySleepAssertionID))")
                ProcessInfo.processInfo.disableAutomaticTermination("Caffeine is preventing sleep")
                updateIcon(active: true)
            } else {
                IOPMAssertionRelease(systemSleepAssertionID)
                systemSleepAssertionID = 0
                print("Failed to enable display sleep prevention (IOKit error: \(displaySleepResult))")
                isPreventingSleep = false
            }
        } else {
            releaseAssertion(&systemSleepAssertionID)
            releaseAssertion(&displaySleepAssertionID)
            ProcessInfo.processInfo.enableAutomaticTermination("Caffeine is preventing sleep")
            print("Sleep prevention disabled")
            updateIcon(active: false)
        }
        
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
    
    func updateIcon(active: Bool) {
        if let button = statusItem.button {
            let symbolName = active ? "cup.and.saucer.fill" : "cup.and.saucer"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: active ? "Active" : "Inactive")
            button.image?.size = NSSize(width: 18, height: 18)
        }
    }
    
    @objc func quit() {
        if isPreventingSleep {
            releaseAssertion(&systemSleepAssertionID)
            releaseAssertion(&displaySleepAssertionID)
        }
        NSApplication.shared.terminate(nil)
    }
}

// Create and run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
