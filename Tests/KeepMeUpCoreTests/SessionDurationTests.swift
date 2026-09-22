import Testing

@testable import KeepMeUpCore

/// Verifies user-visible session presets and launch/manual defaults.
@Suite("Session durations")
struct SessionDurationTests {
  /// Confirms the manual toggle starts the requested 30-minute default.
  @Test("Manual sessions default to 30 minutes")
  func testManualDefaultIsThirtyMinutes() {
    #expect(SessionDuration.manualDefault == .thirtyMinutes)
    #expect(SessionDuration.manualDefault.interval == 1_800)
  }

  /// Confirms every app launch starts an indefinite session.
  @Test("Application launches default to indefinite sessions")
  func testLaunchDefaultIsUntilTurnedOff() {
    #expect(SessionDuration.launchDefault == .untilTurnedOff)
    #expect(SessionDuration.launchDefault.interval == nil)
  }

  /// Confirms the longer duration presets convert to the expected seconds.
  @Test("Longer presets expose exact intervals")
  func testLongerPresetIntervals() {
    #expect(SessionDuration.oneHour.interval == 3_600)
    #expect(SessionDuration.twoHours.interval == 7_200)
  }
}
