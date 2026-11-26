import Foundation
import AppKit
import IOKit
import IOKit.ps

/// System helpers for Hyper mode: the privileged `disablesleep` toggle that makes
/// lid-closed sleep go away, plus battery and lid state for the guards.
enum HyperMode {
    static let sudoersPath = "/etc/sudoers.d/caffeine"

    /// True once the passwordless sudoers rule has been installed on this Mac.
    static var isSetUp: Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
    }

    /// Run a command synchronously and return its exit status (-1 when it cannot run).
    @discardableResult
    static func run(_ path: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Toggle lid-closed sleep. Requires the sudoers rule; `-n` fails instead of prompting.
    static func setSleepDisabled(_ disabled: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"]) == 0
    }

    enum SetupResult {
        case installed
        case cancelled
        case failed(String)
    }

    /// Install `/etc/sudoers.d/caffeine`, asking for an administrator password once.
    static func installSudoersRule() -> SetupResult {
        let user = NSUserName()
        guard user.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
            return .failed("Unsupported user name: \(user)")
        }

        let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
        // No double quotes or backslashes, so the AppleScript string needs no escaping.
        let command = "TMP=$(/usr/bin/mktemp /tmp/caffeine-sudoers.XXXXXX) && "
            + "echo '\(rule)' > $TMP && "
            + "/usr/sbin/visudo -cf $TMP && "
            + "/usr/bin/install -m 0440 -o root -g wheel $TMP /etc/sudoers.d/caffeine; "
            + "STATUS=$?; /bin/rm -f $TMP; exit $STATUS"
        let source = "do shell script \"\(command)\" with administrator privileges "
            + "with prompt \"Caffeine needs administrator access once to allow Hyper mode.\""

        guard let script = NSAppleScript(source: source) else {
            return .failed("Could not build the setup script")
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == -128 {
                return .cancelled
            }
            return .failed(error[NSAppleScript.errorMessage] as? String ?? "Unknown error")
        }
        return .installed
    }

    struct BatteryStatus {
        let onBattery: Bool
        let percent: Int
    }

    /// Internal battery state; nil on Macs without one.
    static func batteryStatus() -> BatteryStatus? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            guard (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else {
                continue
            }
            guard let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int,
                  maximum > 0 else {
                continue
            }
            let onBattery = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSBatteryPowerValue
            return BatteryStatus(onBattery: onBattery, percent: current * 100 / maximum)
        }
        return nil
    }

    /// `AppleClamshellState` from IOPMrootDomain; false when unknown.
    static func isLidClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Bool ?? false
    }
}
