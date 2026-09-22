import Foundation
import IOKit.pwr_mgt

/// Describes a failure to acquire a native macOS power-management assertion.
enum SleepAssertionError: LocalizedError {
  case creationFailed(kind: String, code: IOReturn)

  /// Provides a user-facing explanation for a failed assertion request.
  var errorDescription: String? {
    switch self {
    case .creationFailed(let kind, let code):
      return "KeepMeUp could not prevent \(kind) sleep (IOKit error \(code))."
    }
  }
}

/// Owns and releases the IOKit assertions that prevent idle system and display sleep.
final class SleepAssertionController {
  /// The active assertion that prevents idle system sleep while allowing display sleep.
  private var systemAssertionID: IOPMAssertionID?

  /// The optional active assertion that also prevents idle display sleep.
  private var displayAssertionID: IOPMAssertionID?

  /// Acquires the assertion that keeps the system awake because of user inactivity.
  func preventSystemSleep() throws {
    guard systemAssertionID == nil else {
      return
    }

    systemAssertionID = try createAssertion(
      type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
      kind: "system",
      reason: "KeepMeUp has an active awake session."
    )
  }

  /// Acquires the separate assertion that prevents the display from sleeping.
  func preventDisplaySleep() throws {
    guard displayAssertionID == nil else {
      return
    }

    displayAssertionID = try createAssertion(
      type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
      kind: "display",
      reason: "KeepMeUp display-sleep prevention is enabled."
    )
  }

  /// Releases only the display-sleep assertion while preserving system wakefulness.
  func allowDisplaySleep() {
    releaseAssertion(&displayAssertionID)
  }

  /// Releases every assertion so macOS can resume its normal power-management policy.
  func releaseAll() {
    releaseAssertion(&displayAssertionID)
    releaseAssertion(&systemAssertionID)
  }

  /// Creates one named IOKit assertion and translates a native error into an application error.
  private func createAssertion(type: CFString, kind: String, reason: String) throws
    -> IOPMAssertionID
  {
    var assertionID = IOPMAssertionID(0)
    let result = IOPMAssertionCreateWithName(
      type,
      IOPMAssertionLevel(kIOPMAssertionLevelOn),
      reason as CFString,
      &assertionID
    )

    guard result == kIOReturnSuccess else {
      throw SleepAssertionError.creationFailed(kind: kind, code: result)
    }

    return assertionID
  }

  /// Releases a native assertion and clears its stored identifier even if macOS reports an error.
  private func releaseAssertion(_ assertionID: inout IOPMAssertionID?) {
    guard let activeAssertionID = assertionID else {
      return
    }

    IOPMAssertionRelease(activeAssertionID)
    assertionID = nil
  }

  /// Ensures no sleep-prevention assertion survives the controller's lifetime.
  deinit {
    releaseAll()
  }
}
