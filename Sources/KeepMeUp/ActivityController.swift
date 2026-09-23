import AppKit
import CoreGraphics
import KeepMeUpCore

/// Describes the user-visible runtime state of the optional activity-pulse feature.
enum ActivityModeState: Equatable {
  case off
  case waitingForAwakeSession
  case permissionRequired
  case paused
  case active
  case failed
}

/// Captures immutable activity-mode state for menu rendering and error presentation.
struct ActivityModeSnapshot {
  /// Indicates whether the user wants activity maintenance enabled across launches.
  let isEnabled: Bool

  /// Indicates whether macOS currently permits this process to post pointer events.
  let hasPostEventAccess: Bool

  /// Identifies the effective runtime state after lifecycle and permission checks.
  let state: ActivityModeState

  /// Provides the latest local pulse error without writing diagnostic data to disk.
  let errorDescription: String?
}

/// Describes failures that can occur while constructing a non-clicking pointer pulse.
enum ActivityPulseError: LocalizedError {
  case eventSourceUnavailable
  case pointerLocationUnavailable
  case pointerEventUnavailable

  /// Provides a concise explanation suitable for the menu-bar error alert.
  var errorDescription: String? {
    switch self {
    case .eventSourceUnavailable:
      return "KeepMeUp could not create a macOS input-event source."
    case .pointerLocationUnavailable:
      return "KeepMeUp could not read the current pointer location."
    case .pointerEventUnavailable:
      return "KeepMeUp could not create a safe pointer-move event."
    }
  }
}

/// Owns consent, lifecycle monitoring, idle checks, and minimal non-clicking activity pulses.
final class ActivityController {
  /// Invoked whenever the menu should refresh its activity-mode presentation.
  var onStateChange: (() -> Void)?

  /// The preference store used to retain explicit activity consent and desired state.
  private let preferences: UserDefaults

  /// The pure scheduling policy shared with deterministic unit tests.
  private let policy: ActivityPulsePolicy

  /// The workspace notification source used to pause during inactive GUI sessions.
  private let workspaceNotifications: NotificationCenter

  /// Observer registrations retained until controller teardown.
  private var workspaceObservers: [NSObjectProtocol] = []

  /// The repeating idle evaluator, present only while every runtime condition is satisfied.
  private var evaluationTimer: Timer?

  /// Tracks whether KeepMeUp currently owns an awake session.
  private var awakeSessionIsActive = false

  /// Tracks fast-user-switching and lock-related session inactivity notifications.
  private var userSessionIsActive = true

  /// Tracks display sleep so the app never wakes a sleeping or locked display with generated input.
  private var displayIsAwake = true

  /// Retains only the latest in-memory pulse failure for user-requested inspection.
  private var lastPulseError: Error?

  /// Represents Core Graphics' documented sentinel for any keyboard, mouse, or tablet input.
  private let anyInputEventType = CGEventType(rawValue: UInt32.max)!

  /// Marks generated events so future diagnostics can distinguish KeepMeUp activity pulses.
  private let eventUserDataMarker: Int64 = 0x4B4D_5550

  /// Creates an activity controller and subscribes to active-session and display lifecycle events.
  init(
    preferences: UserDefaults = .standard,
    policy: ActivityPulsePolicy = .standard,
    workspaceNotifications: NotificationCenter = NSWorkspace.shared.notificationCenter
  ) {
    self.preferences = preferences
    self.policy = policy
    self.workspaceNotifications = workspaceNotifications
    observeWorkspaceLifecycle()
  }

  /// Returns the current persisted intent, permission, runtime state, and latest local error.
  var snapshot: ActivityModeSnapshot {
    let isEnabled = preferences.bool(forKey: AppConstants.maintainActivityKey)
    let hasAccess = CGPreflightPostEventAccess()
    let state: ActivityModeState

    if !isEnabled {
      state = .off
    } else if !hasAccess {
      state = .permissionRequired
    } else if !awakeSessionIsActive {
      state = .waitingForAwakeSession
    } else if !userSessionIsActive || !displayIsAwake {
      state = .paused
    } else if lastPulseError != nil {
      state = .failed
    } else {
      state = .active
    }

    return ActivityModeSnapshot(
      isEnabled: isEnabled,
      hasPostEventAccess: hasAccess,
      state: state,
      errorDescription: lastPulseError?.localizedDescription
    )
  }

  /// Indicates whether the one-time explanation must precede the first enable request.
  var needsExplanation: Bool {
    !preferences.bool(forKey: AppConstants.completedActivityExplanationKey)
  }

  /// Records that the user accepted the transparent first-use activity explanation.
  func recordExplanationAccepted() {
    preferences.set(true, forKey: AppConstants.completedActivityExplanationKey)
  }

  /// Persists the requested mode and starts or stops evaluation according to current conditions.
  func setEnabled(_ enabled: Bool) {
    preferences.set(enabled, forKey: AppConstants.maintainActivityKey)
    lastPulseError = nil
    synchronizeRuntimeState()
  }

  /// Requests macOS post-event access only after the app's own consent explanation is accepted.
  @discardableResult
  func requestPostEventAccess() -> Bool {
    if !CGPreflightPostEventAccess() {
      _ = CGRequestPostEventAccess()
    }

    synchronizeRuntimeState()
    return CGPreflightPostEventAccess()
  }

  /// Opens the macOS Accessibility privacy pane without attempting to alter its authorization.
  func openAccessibilitySettings() {
    guard
      let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      )
    else {
      return
    }

    NSWorkspace.shared.open(settingsURL)
  }

  /// Starts activity evaluation for a newly active KeepMeUp awake session when consent permits it.
  func beginAwakeSession() {
    awakeSessionIsActive = true
    lastPulseError = nil
    synchronizeRuntimeState()
  }

  /// Stops all generated activity immediately when the KeepMeUp awake session ends.
  func endAwakeSession() {
    awakeSessionIsActive = false
    stopEvaluationTimer()
    onStateChange?()
  }

  /// Rechecks a permission that may have changed while System Settings was open.
  func refreshAuthorization() {
    synchronizeRuntimeState()
  }

  /// Registers main-thread observers that prevent pulses during inactive or sleeping sessions.
  private func observeWorkspaceLifecycle() {
    let resignObserver = workspaceNotifications.addObserver(
      forName: NSWorkspace.sessionDidResignActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.setUserSessionActive(false)
    }
    workspaceObservers.append(resignObserver)

    let becomeObserver = workspaceNotifications.addObserver(
      forName: NSWorkspace.sessionDidBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.setUserSessionActive(true)
    }
    workspaceObservers.append(becomeObserver)

    let sleepObserver = workspaceNotifications.addObserver(
      forName: NSWorkspace.screensDidSleepNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.setDisplayAwake(false)
    }
    workspaceObservers.append(sleepObserver)

    let wakeObserver = workspaceNotifications.addObserver(
      forName: NSWorkspace.screensDidWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.setDisplayAwake(true)
    }
    workspaceObservers.append(wakeObserver)
  }

  /// Applies a user-session lifecycle change and reevaluates whether the timer may run.
  private func setUserSessionActive(_ isActive: Bool) {
    userSessionIsActive = isActive
    synchronizeRuntimeState()
  }

  /// Applies a display lifecycle change and reevaluates whether the timer may run.
  private func setDisplayAwake(_ isAwake: Bool) {
    displayIsAwake = isAwake
    synchronizeRuntimeState()
  }

  /// Starts exactly one evaluator when enabled, authorized, awake, and in the active GUI session.
  private func synchronizeRuntimeState() {
    let shouldEvaluate =
      preferences.bool(forKey: AppConstants.maintainActivityKey)
      && awakeSessionIsActive
      && userSessionIsActive
      && displayIsAwake
      && CGPreflightPostEventAccess()

    if shouldEvaluate {
      startEvaluationTimerIfNeeded()
    } else {
      stopEvaluationTimer()
    }

    onStateChange?()
  }

  /// Creates the common-run-loop timer and immediately evaluates an already-idle session.
  private func startEvaluationTimerIfNeeded() {
    guard evaluationTimer == nil else {
      return
    }

    evaluateActivityPulse()
    let timer = Timer(timeInterval: policy.pollingInterval, repeats: true) { [weak self] _ in
      self?.evaluateActivityPulse()
    }
    evaluationTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  /// Invalidates and discards the activity evaluator without changing the saved preference.
  private func stopEvaluationTimer() {
    evaluationTimer?.invalidate()
    evaluationTimer = nil
  }

  /// Evaluates current idle and safety conditions before posting one reversible pointer pulse.
  private func evaluateActivityPulse() {
    let hasAccess = CGPreflightPostEventAccess()
    let idleTime = CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: anyInputEventType
    )
    let mouseButtonIsPressed =
      CGEventSource.buttonState(.combinedSessionState, button: .left)
      || CGEventSource.buttonState(.combinedSessionState, button: .right)
      || CGEventSource.buttonState(.combinedSessionState, button: .center)

    guard
      policy.shouldPostPulse(
        idleTime: idleTime,
        awakeSessionIsActive: awakeSessionIsActive,
        userSessionIsActive: userSessionIsActive,
        displayIsAwake: displayIsAwake,
        hasPostEventAccess: hasAccess,
        mouseButtonIsPressed: mouseButtonIsPressed
      )
    else {
      if !hasAccess {
        stopEvaluationTimer()
        onStateChange?()
      }
      return
    }

    do {
      try postPointerPulse()
      lastPulseError = nil
    } catch {
      lastPulseError = error
      stopEvaluationTimer()
      onStateChange?()
    }
  }

  /// Posts one one-pixel mouse move and an immediate return without clicks, keys, or pointer drift.
  private func postPointerPulse() throws {
    guard let source = CGEventSource(stateID: .combinedSessionState) else {
      throw ActivityPulseError.eventSourceUnavailable
    }
    guard let locationEvent = CGEvent(source: nil) else {
      throw ActivityPulseError.pointerLocationUnavailable
    }

    let originalLocation = locationEvent.location
    let horizontalOffset: CGFloat = originalLocation.x > 0 ? -1 : 1
    let nudgedLocation = CGPoint(
      x: originalLocation.x + horizontalOffset,
      y: originalLocation.y
    )
    guard
      let outwardEvent = CGEvent(
        mouseEventSource: source,
        mouseType: .mouseMoved,
        mouseCursorPosition: nudgedLocation,
        mouseButton: .left
      ),
      let returnEvent = CGEvent(
        mouseEventSource: source,
        mouseType: .mouseMoved,
        mouseCursorPosition: originalLocation,
        mouseButton: .left
      )
    else {
      throw ActivityPulseError.pointerEventUnavailable
    }

    // A marker supports local debugging without observing, storing, or transmitting user input.
    outwardEvent.setIntegerValueField(.eventSourceUserData, value: eventUserDataMarker)
    returnEvent.setIntegerValueField(.eventSourceUserData, value: eventUserDataMarker)
    outwardEvent.post(tap: .cghidEventTap)
    returnEvent.post(tap: .cghidEventTap)
  }

  /// Removes observers and guarantees no timer survives the controller's lifetime.
  deinit {
    stopEvaluationTimer()
    for observer in workspaceObservers {
      workspaceNotifications.removeObserver(observer)
    }
  }
}
