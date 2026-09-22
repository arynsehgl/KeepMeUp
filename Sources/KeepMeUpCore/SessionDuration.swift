import Foundation

/// Represents the user-selectable lifetime of an awake session.
public enum SessionDuration: String, CaseIterable, Equatable, Sendable {
  case thirtyMinutes
  case oneHour
  case twoHours
  case untilTurnedOff

  /// The duration used when a user manually starts a stopped session.
  public static let manualDefault: SessionDuration = .thirtyMinutes

  /// The duration used whenever the application itself launches.
  public static let launchDefault: SessionDuration = .untilTurnedOff

  /// Returns the number of seconds before expiration, or `nil` for an indefinite session.
  public var interval: TimeInterval? {
    switch self {
    case .thirtyMinutes:
      return 30 * 60
    case .oneHour:
      return 60 * 60
    case .twoHours:
      return 2 * 60 * 60
    case .untilTurnedOff:
      return nil
    }
  }

  /// Returns the title displayed for the duration in the menu.
  public var title: String {
    switch self {
    case .thirtyMinutes:
      return "30 Minutes"
    case .oneHour:
      return "1 Hour"
    case .twoHours:
      return "2 Hours"
    case .untilTurnedOff:
      return "Until Turned Off"
    }
  }
}
