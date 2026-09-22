import AppKit

/// Presents the one-time explanation, notification request, and Login Item consent flow.
final class FirstRunCoordinator {
  /// The preference store that prevents onboarding from repeating after completion.
  private let preferences: UserDefaults

  /// Creates a first-run coordinator backed by the standard application preferences.
  init(preferences: UserDefaults = .standard) {
    self.preferences = preferences
  }

  /// Presents onboarding only once and records completion after the user's Login Item decision.
  func presentIfNeeded(
    notifications: NotificationController,
    loginItems: LoginItemController
  ) {
    guard !preferences.bool(forKey: AppConstants.completedFirstLaunchKey) else {
      return
    }

    NSApp.activate(ignoringOtherApps: true)

    let welcomeAlert = NSAlert()
    welcomeAlert.alertStyle = .informational
    welcomeAlert.messageText = "Welcome to KeepMeUp"
    welcomeAlert.informativeText =
      "KeepMeUp has started an awake session. macOS will next ask whether it may notify you when a timed session ends."
    welcomeAlert.addButton(withTitle: "Continue")
    welcomeAlert.runModal()

    notifications.requestAuthorization { [weak self] in
      DispatchQueue.main.async {
        self?.requestLoginItemConsent(loginItems: loginItems)
      }
    }
  }

  /// Asks before registering the app as a Login Item and handles macOS approval requirements.
  private func requestLoginItemConsent(loginItems: LoginItemController) {
    let loginAlert = NSAlert()
    loginAlert.alertStyle = .informational
    loginAlert.messageText = "Start KeepMeUp at Login?"
    loginAlert.informativeText =
      "If enabled, KeepMeUp will launch an Until Turned Off awake session whenever you log in. You can change this later from the menu bar or System Settings."
    loginAlert.addButton(withTitle: "Enable")
    loginAlert.addButton(withTitle: "Not Now")

    if loginAlert.runModal() == .alertFirstButtonReturn {
      do {
        try loginItems.setEnabled(true)

        if loginItems.requiresApproval {
          loginItems.openSystemSettings()
        }
      } catch {
        presentError(title: "Could Not Enable Start at Login", error: error)
      }
    }

    preferences.set(true, forKey: AppConstants.completedFirstLaunchKey)
  }

  /// Displays a local error without logging personal data or system configuration.
  private func presentError(title: String, error: Error) {
    let alert = NSAlert(error: error)
    alert.messageText = title
    alert.runModal()
  }
}
