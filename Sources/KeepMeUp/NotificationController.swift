import AppKit
import Foundation
import UserNotifications

/// Requests notification permission and sends local session or update notifications.
final class NotificationController: NSObject, UNUserNotificationCenterDelegate {
  /// The system notification center used for authorization and delivery.
  private let center = UNUserNotificationCenter.current()

  /// Configures the controller as the delegate so banners can appear while the utility is active.
  override init() {
    super.init()
    center.delegate = self
  }

  /// Requests alert and sound authorization, invoking completion after macOS resolves the request.
  func requestAuthorization(completion: @escaping () -> Void) {
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in
      completion()
    }
  }

  /// Posts the single notification requested when a timed awake session expires.
  func postTimedSessionEnded() {
    let content = UNMutableNotificationContent()
    content.title = "KeepMeUp Session Ended"
    content.body = "Your timed awake session has finished. Normal sleep behavior is restored."
    content.sound = .default
    center.add(UNNotificationRequest(identifier: "session-ended", content: content, trigger: nil))
  }

  /// Posts a once-per-version notification that links to the matching GitHub release.
  func postUpdateAvailable(version: String, releaseURL: URL) {
    let content = UNMutableNotificationContent()
    content.title = "KeepMeUp Update Available"
    content.body = "Version \(version) is available to download from GitHub."
    content.sound = .default
    content.userInfo = ["releaseURL": releaseURL.absoluteString]
    center.add(
      UNNotificationRequest(identifier: "update-\(version)", content: content, trigger: nil))
  }

  /// Displays notifications as banners even though the menu-bar utility is currently running.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  /// Opens the GitHub release when a user clicks an update notification.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let rawURL = response.notification.request.content.userInfo["releaseURL"] as? String,
      let releaseURL = URL(string: rawURL)
    {
      DispatchQueue.main.async {
        NSWorkspace.shared.open(releaseURL)
      }
    }
    completionHandler()
  }
}
