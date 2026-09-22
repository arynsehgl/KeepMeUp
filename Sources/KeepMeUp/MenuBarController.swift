import AppKit
import KeepMeUpCore

/// Builds and updates the complete menu-bar-only user interface.
final class MenuBarController: NSObject, NSMenuDelegate {
  /// The persistent system status item that displays only an icon.
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

  /// The pull-down menu rebuilt whenever the user opens it.
  private let menu = NSMenu()

  /// The active-session coordinator that powers menu state and actions.
  private let sessions: SessionController

  /// The native Login Item interface reflected by the menu toggle.
  private let loginItems: LoginItemController

  /// The local notification service used for timers and update availability.
  private let notifications: NotificationController

  /// The public GitHub release checker used at launch and on demand.
  private let updateChecker: GitHubUpdateChecker

  /// The latest release determined to be newer than the running application.
  private var availableRelease: GitHubRelease?

  /// The status line retained so countdown ticks can update it while the menu is open.
  private weak var statusMenuItem: NSMenuItem?

  /// Creates the controller and wires all state-change callbacks before presenting the icon.
  init(
    sessions: SessionController,
    loginItems: LoginItemController,
    notifications: NotificationController,
    updateChecker: GitHubUpdateChecker
  ) {
    self.sessions = sessions
    self.loginItems = loginItems
    self.notifications = notifications
    self.updateChecker = updateChecker
    super.init()

    menu.delegate = self
    menu.autoenablesItems = false
    statusItem.menu = menu
    sessions.onStateChange = { [weak self] in
      self?.refreshStatusPresentation()
    }
    sessions.onTimedSessionEnded = { [weak self] in
      self?.notifications.postTimedSessionEnded()
    }
    refreshStatusPresentation()
  }

  /// Rebuilds the menu immediately before display so every toggle reflects macOS state.
  func menuNeedsUpdate(_ menu: NSMenu) {
    rebuildMenu()
  }

  /// Performs the silent launch-time update lookup requested for the first release.
  func checkForUpdatesAtLaunch() {
    performUpdateCheck(showCompletionAlert: false)
  }

  /// Constructs all menu rows in their intended order and enabled state.
  private func rebuildMenu() {
    menu.removeAllItems()
    let snapshot = sessions.snapshot

    let status = NSMenuItem(title: statusTitle(for: snapshot), action: nil, keyEquivalent: "")
    status.isEnabled = false
    menu.addItem(status)
    statusMenuItem = status
    menu.addItem(.separator())

    let awakeToggle = NSMenuItem(
      title: "Keep Mac Awake",
      action: #selector(toggleAwake),
      keyEquivalent: ""
    )
    awakeToggle.target = self
    awakeToggle.state = snapshot.isActive ? .on : .off
    awakeToggle.isEnabled = true
    menu.addItem(awakeToggle)

    let durationMenuItem = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
    durationMenuItem.submenu = makeDurationMenu(snapshot: snapshot)
    durationMenuItem.isEnabled = snapshot.isActive
    menu.addItem(durationMenuItem)

    let displayToggle = NSMenuItem(
      title: "Prevent Display Sleep",
      action: #selector(toggleDisplaySleep),
      keyEquivalent: ""
    )
    displayToggle.target = self
    displayToggle.state = snapshot.preventsDisplaySleep ? .on : .off
    displayToggle.isEnabled = snapshot.isActive
    menu.addItem(displayToggle)
    menu.addItem(.separator())

    let loginToggle = NSMenuItem(
      title: loginItems.requiresApproval ? "Start at Login (Approval Required)" : "Start at Login",
      action: #selector(toggleStartAtLogin),
      keyEquivalent: ""
    )
    loginToggle.target = self
    loginToggle.state = loginItems.isEnabled ? .on : .off
    loginToggle.isEnabled = true
    menu.addItem(loginToggle)

    let loginSettings = NSMenuItem(
      title: "Open Login Items Settings…",
      action: #selector(openLoginItemSettings),
      keyEquivalent: ""
    )
    loginSettings.target = self
    loginSettings.isEnabled = true
    menu.addItem(loginSettings)
    menu.addItem(.separator())

    if let availableRelease {
      let updateItem = NSMenuItem(
        title: "Update Available: \(availableRelease.tagName)",
        action: #selector(openAvailableUpdate),
        keyEquivalent: ""
      )
      updateItem.target = self
      updateItem.isEnabled = true
      menu.addItem(updateItem)
    }

    let checkForUpdates = NSMenuItem(
      title: "Check for Updates…",
      action: #selector(checkForUpdatesManually),
      keyEquivalent: ""
    )
    checkForUpdates.target = self
    checkForUpdates.isEnabled = true
    menu.addItem(checkForUpdates)

    let about = NSMenuItem(title: "About KeepMeUp", action: #selector(showAbout), keyEquivalent: "")
    about.target = self
    about.isEnabled = true
    menu.addItem(about)

    let quit = NSMenuItem(
      title: "Quit KeepMeUp", action: #selector(quitApplication), keyEquivalent: "q")
    quit.target = self
    quit.isEnabled = true
    menu.addItem(quit)
  }

  /// Creates the enabled duration submenu and checks the current duration choice.
  private func makeDurationMenu(snapshot: SessionSnapshot) -> NSMenu {
    let durationMenu = NSMenu(title: "Duration")
    durationMenu.autoenablesItems = false

    for duration in SessionDuration.allCases {
      let item = NSMenuItem(
        title: duration.title, action: #selector(selectDuration(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = duration.rawValue
      item.state = snapshot.duration == duration ? .on : .off
      item.isEnabled = snapshot.isActive
      durationMenu.addItem(item)
    }

    return durationMenu
  }

  /// Starts the manual default timer or stops the currently active session.
  @objc private func toggleAwake() {
    if sessions.snapshot.isActive {
      sessions.stop()
    } else {
      startSession(duration: .manualDefault)
    }
  }

  /// Replaces the active duration with a fresh countdown beginning at selection time.
  @objc private func selectDuration(_ sender: NSMenuItem) {
    guard sessions.snapshot.isActive,
      let rawValue = sender.representedObject as? String,
      let duration = SessionDuration(rawValue: rawValue)
    else {
      return
    }

    startSession(duration: duration)
  }

  /// Applies or removes display-sleep prevention and retains the user's preference.
  @objc private func toggleDisplaySleep() {
    let desiredState = !sessions.snapshot.preventsDisplaySleep

    do {
      try sessions.setPreventDisplaySleep(desiredState)
    } catch {
      presentError(title: "Could Not Change Display Sleep", error: error)
    }
  }

  /// Updates native Login Item registration and directs the user to approval when required.
  @objc private func toggleStartAtLogin() {
    do {
      try loginItems.setEnabled(!loginItems.isEnabled)

      if loginItems.requiresApproval {
        loginItems.openSystemSettings()
      }
    } catch {
      presentError(title: "Could Not Change Start at Login", error: error)
    }

    rebuildMenu()
  }

  /// Opens the macOS Login Items settings page without changing registration.
  @objc private func openLoginItemSettings() {
    loginItems.openSystemSettings()
  }

  /// Runs an interactive update check and reports every outcome to the user.
  @objc private func checkForUpdatesManually() {
    performUpdateCheck(showCompletionAlert: true)
  }

  /// Opens the latest known release page for manual download and installation.
  @objc private func openAvailableUpdate() {
    NSWorkspace.shared.open(availableRelease?.pageURL ?? AppConstants.repositoryURL)
  }

  /// Displays the standard AppKit About panel with version and project information.
  @objc private func showAbout() {
    NSApp.orderFrontStandardAboutPanel(options: [
      .applicationName: "KeepMeUp",
      .applicationVersion: AppConstants.currentVersion,
      .credits: NSAttributedString(string: "A private, open-source macOS awake-session utility."),
    ])
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Terminates the utility, allowing the app delegate to release active assertions.
  @objc private func quitApplication() {
    NSApp.terminate(nil)
  }

  /// Starts a requested duration and presents any native assertion failure.
  private func startSession(duration: SessionDuration) {
    do {
      try sessions.start(duration: duration)
    } catch {
      presentError(title: "Could Not Start Awake Session", error: error)
    }
  }

  /// Updates the icon and any visible status line without showing menu-bar text.
  private func refreshStatusPresentation() {
    let snapshot = sessions.snapshot
    let symbolName = snapshot.isActive ? "bolt.circle.fill" : "moon.zzz"
    statusItem.button?.image = NSImage(
      systemSymbolName: symbolName,
      accessibilityDescription: snapshot.isActive ? "KeepMeUp active" : "KeepMeUp inactive"
    )
    statusItem.button?.toolTip = statusTitle(for: snapshot)
    statusMenuItem?.title = statusTitle(for: snapshot)
  }

  /// Formats the current active state or countdown for display inside the dropdown.
  private func statusTitle(for snapshot: SessionSnapshot) -> String {
    guard snapshot.isActive else {
      return "Status: Off"
    }

    guard let remainingTime = snapshot.remainingTime() else {
      return "Status: Awake — Until Turned Off"
    }

    let totalSeconds = max(0, Int(ceil(remainingTime)))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    let countdown =
      hours > 0
      ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
      : String(format: "%02d:%02d", minutes, seconds)
    return "Status: Awake — \(countdown) remaining"
  }

  /// Checks GitHub and either updates menu state silently or presents a requested result alert.
  private func performUpdateCheck(showCompletionAlert: Bool) {
    updateChecker.check { [weak self] result in
      guard let self else {
        return
      }

      switch result {
      case .success(.updateAvailable(let release)):
        self.availableRelease = release
        self.notifyAboutUpdateIfNeeded(release)
        self.rebuildMenu()

        if showCompletionAlert {
          self.presentUpdateAvailable(release)
        }
      case .success(.upToDate):
        self.availableRelease = nil
        self.rebuildMenu()

        if showCompletionAlert {
          self.presentMessage(
            title: "KeepMeUp Is Up to Date",
            message: "You are running version \(AppConstants.currentVersion)."
          )
        }
      case .success(.noPublishedRelease):
        if showCompletionAlert {
          self.presentMessage(
            title: "No Published Release Yet",
            message: "GitHub does not currently have a published KeepMeUp release."
          )
        }
      case .failure(let error):
        if showCompletionAlert {
          self.presentError(title: "Could Not Check for Updates", error: error)
        }
      }
    }
  }

  /// Sends one notification per newer release instead of notifying on every app launch.
  private func notifyAboutUpdateIfNeeded(_ release: GitHubRelease) {
    let preferences = UserDefaults.standard

    guard preferences.string(forKey: AppConstants.lastNotifiedVersionKey) != release.tagName else {
      return
    }

    notifications.postUpdateAvailable(version: release.tagName, releaseURL: release.pageURL)
    preferences.set(release.tagName, forKey: AppConstants.lastNotifiedVersionKey)
  }

  /// Presents an update alert that can open the release page without downloading automatically.
  private func presentUpdateAvailable(_ release: GitHubRelease) {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "KeepMeUp \(release.tagName) Is Available"
    alert.informativeText = "The update can be downloaded and installed manually from GitHub."
    alert.addButton(withTitle: "Open Release")
    alert.addButton(withTitle: "Later")

    if alert.runModal() == .alertFirstButtonReturn {
      NSWorkspace.shared.open(release.pageURL)
    }
  }

  /// Presents a simple informational alert for successful manual operations.
  private func presentMessage(title: String, message: String) {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = title
    alert.informativeText = message
    alert.runModal()
  }

  /// Presents a concise error alert while avoiding console logs or response-body disclosure.
  private func presentError(title: String, error: Error) {
    let alert = NSAlert(error: error)
    alert.messageText = title
    alert.runModal()
  }
}
