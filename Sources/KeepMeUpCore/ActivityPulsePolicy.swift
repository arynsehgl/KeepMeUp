import Foundation

/// Defines when KeepMeUp may post a minimal activity pulse after genuine input has stopped.
public struct ActivityPulsePolicy: Equatable, Sendable {
  /// The default policy refreshes activity conservatively while minimizing generated input.
  public static let standard = ActivityPulsePolicy(
    inactivityThreshold: 240,
    pollingInterval: 60
  )

  /// The number of idle seconds required before an activity pulse is eligible.
  public let inactivityThreshold: TimeInterval

  /// The interval between lightweight eligibility checks.
  public let pollingInterval: TimeInterval

  /// Creates a policy with positive timing values suitable for a repeating scheduler.
  public init(inactivityThreshold: TimeInterval, pollingInterval: TimeInterval) {
    precondition(inactivityThreshold > 0, "The inactivity threshold must be positive.")
    precondition(pollingInterval > 0, "The polling interval must be positive.")
    self.inactivityThreshold = inactivityThreshold
    self.pollingInterval = pollingInterval
  }

  /// Returns whether every lifecycle, permission, input, and timing condition permits a pulse.
  public func shouldPostPulse(
    idleTime: TimeInterval,
    awakeSessionIsActive: Bool,
    userSessionIsActive: Bool,
    displayIsAwake: Bool,
    hasPostEventAccess: Bool,
    mouseButtonIsPressed: Bool
  ) -> Bool {
    awakeSessionIsActive
      && userSessionIsActive
      && displayIsAwake
      && hasPostEventAccess
      && !mouseButtonIsPressed
      && idleTime >= inactivityThreshold
  }
}
