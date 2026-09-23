import Testing

@testable import KeepMeUpCore

/// Verifies that activity pulses occur only under explicitly safe runtime conditions.
@Suite("Activity pulse policy")
struct ActivityPulsePolicyTests {
  /// A compact policy keeps boundary-focused tests independent of production timing.
  private let policy = ActivityPulsePolicy(inactivityThreshold: 240, pollingInterval: 60)

  /// Confirms an eligible awake and unlocked session pulses exactly at the idle threshold.
  @Test("Posts at the inactivity threshold")
  func testPostsAtThreshold() {
    #expect(
      policy.shouldPostPulse(
        idleTime: 240,
        awakeSessionIsActive: true,
        userSessionIsActive: true,
        displayIsAwake: true,
        hasPostEventAccess: true,
        mouseButtonIsPressed: false
      )
    )
  }

  /// Confirms genuine recent keyboard or pointer use suppresses an unnecessary synthetic pulse.
  @Test("Skips while genuine activity is recent")
  func testSkipsRecentActivity() {
    #expect(
      !policy.shouldPostPulse(
        idleTime: 239,
        awakeSessionIsActive: true,
        userSessionIsActive: true,
        displayIsAwake: true,
        hasPostEventAccess: true,
        mouseButtonIsPressed: false
      )
    )
  }

  /// Confirms stopping KeepMeUp's awake session also disables its activity scheduler.
  @Test("Skips when the awake session is off")
  func testSkipsWithoutAwakeSession() {
    #expect(
      !policy.shouldPostPulse(
        idleTime: 300,
        awakeSessionIsActive: false,
        userSessionIsActive: true,
        displayIsAwake: true,
        hasPostEventAccess: true,
        mouseButtonIsPressed: false
      )
    )
  }

  /// Confirms an inactive or locked user session never receives generated input.
  @Test("Skips when the user session is inactive")
  func testSkipsInactiveUserSession() {
    #expect(
      !policy.shouldPostPulse(
        idleTime: 300,
        awakeSessionIsActive: true,
        userSessionIsActive: false,
        displayIsAwake: true,
        hasPostEventAccess: true,
        mouseButtonIsPressed: false
      )
    )
  }

  /// Confirms display sleep pauses activity generation until the workspace reports a wake.
  @Test("Skips while the display sleeps")
  func testSkipsSleepingDisplay() {
    #expect(
      !policy.shouldPostPulse(
        idleTime: 300,
        awakeSessionIsActive: true,
        userSessionIsActive: true,
        displayIsAwake: false,
        hasPostEventAccess: true,
        mouseButtonIsPressed: false
      )
    )
  }

  /// Confirms denied macOS post-event access cannot produce an activity pulse.
  @Test("Skips without post-event permission")
  func testSkipsWithoutPermission() {
    #expect(
      !policy.shouldPostPulse(
        idleTime: 300,
        awakeSessionIsActive: true,
        userSessionIsActive: true,
        displayIsAwake: true,
        hasPostEventAccess: false,
        mouseButtonIsPressed: false
      )
    )
  }

  /// Confirms a held mouse button suppresses movement that could interfere with a drag operation.
  @Test("Skips while a mouse button is held")
  func testSkipsHeldMouseButton() {
    #expect(
      !policy.shouldPostPulse(
        idleTime: 300,
        awakeSessionIsActive: true,
        userSessionIsActive: true,
        displayIsAwake: true,
        hasPostEventAccess: true,
        mouseButtonIsPressed: true
      )
    )
  }
}
