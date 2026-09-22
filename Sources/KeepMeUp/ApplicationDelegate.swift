import AppKit
import KeepMeUpCore

/// Owns application-lifetime services and starts an indefinite session on every launch.
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
  /// The native power assertion owner shared by all sessions.
  private let sleepAssertions = SleepAssertionController()

  /// The notification service retained for the complete application lifetime.
  private let notifications = NotificationController()

  /// The native Login Item interface retained for menus and onboarding.
  private let loginItems = LoginItemController()

  /// The public release checker retained for launch and manual checks.
  private let updateChecker = GitHubUpdateChecker()

  /// The one-time onboarding flow retained while its asynchronous permission request completes.
  private let firstRun = FirstRunCoordinator()

  /// The session state owner created after the power controller is initialized.
  private lazy var sessions = SessionController(sleepAssertions: sleepAssertions)

  /// The menu controller retained to keep the status item visible.
  private var menuBarController: MenuBarController?

  /// Configures the menu, starts an indefinite session, checks updates, and presents onboarding.
  func applicationDidFinishLaunching(_ notification: Notification) {
    menuBarController = MenuBarController(
      sessions: sessions,
      loginItems: loginItems,
      notifications: notifications,
      updateChecker: updateChecker
    )

    do {
      try sessions.start(duration: .launchDefault)
    } catch {
      presentLaunchError(error)
    }

    menuBarController?.checkForUpdatesAtLaunch()

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      self.firstRun.presentIfNeeded(notifications: self.notifications, loginItems: self.loginItems)
    }
  }

  /// Releases every active assertion before the process exits.
  func applicationWillTerminate(_ notification: Notification) {
    sessions.stop()
  }

  /// Presents a startup failure after the menu item exists, allowing the user to quit cleanly.
  private func presentLaunchError(_ error: Error) {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert(error: error)
    alert.messageText = "KeepMeUp Could Not Start"
    alert.runModal()
  }
}
