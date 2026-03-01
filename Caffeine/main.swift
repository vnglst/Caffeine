import Cocoa
import IOKit.pwr_mgt

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var isPreventingSleep = false
    var assertionID: IOPMAssertionID = 0
    
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
    
    func setupMenu() {
        let menu = NSMenu()
        
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
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
            let reason = "Caffeine preventing sleep" as CFString
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoIdleSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &assertionID
            )
            
            if result == kIOReturnSuccess {
                print("Sleep prevention enabled")
                updateIcon(active: true)
            } else {
                print("Failed to enable sleep prevention")
                isPreventingSleep = false
            }
        } else {
            IOPMAssertionRelease(assertionID)
            print("Sleep prevention disabled")
            updateIcon(active: false)
        }
        
        setupMenu()
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
            IOPMAssertionRelease(assertionID)
        }
        NSApplication.shared.terminate(nil)
    }
}

// Create and run the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
