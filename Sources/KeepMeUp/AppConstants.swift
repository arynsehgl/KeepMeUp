import Foundation

/// Centralizes stable application metadata, persisted preference keys, and update endpoints.
enum AppConstants {
  /// The current release version used when bundle metadata is unavailable during development.
  static let fallbackVersion = "0.2.0"

  /// The reverse-DNS identifier used by the packaged application.
  static let bundleIdentifier = "com.arynsehgl.keepmeup"

  /// The GitHub account that hosts releases.
  static let repositoryOwner = "arynsehgl"

  /// The canonical GitHub repository name used by update checks and public links.
  static let repositoryName = "KeepMeUp"

  /// Stores whether display-sleep prevention should be restored for the next awake session.
  static let preventDisplaySleepKey = "preventDisplaySleep"

  /// Stores whether the user wants consent-based computer activity maintained during awake sessions.
  static let maintainActivityKey = "maintainActivity"

  /// Stores whether the one-time activity-generation explanation has been accepted.
  static let completedActivityExplanationKey = "completedActivityExplanation"

  /// Stores whether the one-time onboarding experience has been completed.
  static let completedFirstLaunchKey = "completedFirstLaunch"

  /// Stores the release version for which an update notification was most recently shown.
  static let lastNotifiedVersionKey = "lastNotifiedVersion"

  /// Returns the version embedded in the app bundle or the development fallback version.
  static var currentVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? fallbackVersion
  }

  /// Returns the unauthenticated GitHub endpoint for the latest published release.
  static var latestReleaseAPIURL: URL {
    URL(
      string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest")!
  }

  /// Returns the public repository page shown when no release-specific URL is available.
  static var repositoryURL: URL {
    URL(string: "https://github.com/\(repositoryOwner)/\(repositoryName)")!
  }
}
