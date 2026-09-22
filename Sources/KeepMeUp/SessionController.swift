import Foundation
import KeepMeUpCore

/// Captures the current state required to render the menu without exposing mutable controller data.
struct SessionSnapshot: Equatable {
  /// Indicates whether KeepMeUp currently owns a system-sleep assertion.
  let isActive: Bool

  /// Identifies the selected duration for an active session.
  let duration: SessionDuration?

  /// Records the expiration date for a timed session.
  let endDate: Date?

  /// Records the persisted preference for preventing display sleep during active sessions.
  let preventsDisplaySleep: Bool

  /// Returns the nonnegative number of seconds remaining in a timed session.
  func remainingTime(at date: Date = Date()) -> TimeInterval? {
    endDate.map { max(0, $0.timeIntervalSince(date)) }
  }
}

/// Coordinates session timers, persisted display preference, and native sleep assertions.
final class SessionController {
  /// Invoked whenever a state change should be reflected in the menu.
  var onStateChange: (() -> Void)?

  /// Invoked only when a timed session naturally reaches its expiration date.
  var onTimedSessionEnded: (() -> Void)?

  /// The controller that owns native IOKit assertions.
  private let sleepAssertions: SleepAssertionController

  /// The preference store used to remember display-sleep behavior across launches.
  private let preferences: UserDefaults

  /// The selected duration for the active session, or `nil` when stopped.
  private var activeDuration: SessionDuration?

  /// The absolute expiration date for a timed session.
  private var endDate: Date?

  /// The timer that refreshes countdown text and detects expiration.
  private var countdownTimer: Timer?

  /// Creates a session controller with explicit dependencies for predictable lifecycle management.
  init(sleepAssertions: SleepAssertionController, preferences: UserDefaults = .standard) {
    self.sleepAssertions = sleepAssertions
    self.preferences = preferences
  }

  /// Returns an immutable representation of the current session state.
  var snapshot: SessionSnapshot {
    SessionSnapshot(
      isActive: activeDuration != nil,
      duration: activeDuration,
      endDate: endDate,
      preventsDisplaySleep: preferences.bool(forKey: AppConstants.preventDisplaySleepKey)
    )
  }

  /// Starts or replaces a session and applies the remembered display-sleep preference.
  func start(duration: SessionDuration) throws {
    stopCountdownTimer()
    sleepAssertions.releaseAll()

    do {
      try sleepAssertions.preventSystemSleep()

      if preferences.bool(forKey: AppConstants.preventDisplaySleepKey) {
        try sleepAssertions.preventDisplaySleep()
      }
    } catch {
      sleepAssertions.releaseAll()
      activeDuration = nil
      endDate = nil
      onStateChange?()
      throw error
    }

    activeDuration = duration
    endDate = duration.interval.map { Date().addingTimeInterval($0) }
    startCountdownTimerIfNeeded()
    onStateChange?()
  }

  /// Stops the current session and releases both system and display assertions.
  func stop() {
    stopCountdownTimer()
    sleepAssertions.releaseAll()
    activeDuration = nil
    endDate = nil
    onStateChange?()
  }

  /// Changes and persists display-sleep behavior for the current and future sessions.
  func setPreventDisplaySleep(_ enabled: Bool) throws {
    guard activeDuration != nil else {
      return
    }

    if enabled {
      do {
        try sleepAssertions.preventDisplaySleep()
        preferences.set(true, forKey: AppConstants.preventDisplaySleepKey)
      } catch {
        preferences.set(false, forKey: AppConstants.preventDisplaySleepKey)
        throw error
      }
    } else {
      sleepAssertions.allowDisplaySleep()
      preferences.set(false, forKey: AppConstants.preventDisplaySleepKey)
    }

    onStateChange?()
  }

  /// Creates a common-run-loop timer only for sessions that have an expiration date.
  private func startCountdownTimerIfNeeded() {
    guard endDate != nil else {
      return
    }

    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      self?.handleCountdownTick()
    }
    countdownTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  /// Refreshes countdown text and ends the session exactly once after expiration.
  private func handleCountdownTick() {
    guard let endDate else {
      return
    }

    if Date() >= endDate {
      stop()
      onTimedSessionEnded?()
    } else {
      onStateChange?()
    }
  }

  /// Invalidates and discards the current countdown timer.
  private func stopCountdownTimer() {
    countdownTimer?.invalidate()
    countdownTimer = nil
  }

  /// Releases all process-owned power assertions if the controller is destroyed unexpectedly.
  deinit {
    stopCountdownTimer()
    sleepAssertions.releaseAll()
  }
}
