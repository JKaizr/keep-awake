import Foundation
import IOKit.pwr_mgt

/// Thin RAII wrapper around an IOKit power-management assertion
/// (the same mechanism `caffeinate` uses).
///
/// - Creating the object takes the assertion.
/// - Deallocating it releases the assertion.
/// - macOS also drops every assertion of a process automatically when the
///   process quits or crashes, so the Mac can never stay stuck awake.
final class PowerAssertion {
    enum Kind: String {
        /// `kIOPMAssertPreventUserIdleSystemSleep`: the system must not idle-sleep.
        /// The display is still allowed to turn off.
        case preventIdleSystemSleep = "PreventUserIdleSystemSleep"
        /// `kIOPMAssertPreventUserIdleDisplaySleep`: the display must not dim or turn off.
        /// (An awake display also keeps the system from idle-sleeping.)
        case preventIdleDisplaySleep = "PreventUserIdleDisplaySleep"
    }

    let kind: Kind
    private let id: IOPMAssertionID

    /// - Parameter timeout: Optional safety net. macOS itself releases the
    ///   assertion after this many seconds, even if our own timer fails.
    init?(_ kind: Kind, reason: String, timeout: TimeInterval? = nil) {
        var newID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kind.rawValue as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newID
        )
        guard result == kIOReturnSuccess else {
            NSLog("Awake: failed to create %@ assertion (IOReturn %d)", kind.rawValue, result)
            return nil
        }
        self.kind = kind
        self.id = newID

        if let timeout, timeout > 0 {
            // kIOPMAssertionTimeoutKey / kIOPMAssertionTimeoutActionKey / kIOPMAssertionTimeoutActionRelease
            IOPMAssertionSetProperty(newID, "TimeoutSeconds" as CFString, NSNumber(value: timeout))
            IOPMAssertionSetProperty(newID, "TimeoutAction" as CFString, "TimeoutActionRelease" as CFString)
        }
    }

    deinit {
        IOPMAssertionRelease(id)
    }
}
