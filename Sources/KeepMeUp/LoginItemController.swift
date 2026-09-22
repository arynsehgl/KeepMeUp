import Foundation
import ServiceManagement

/// Provides a small native interface to the current app's macOS Login Item registration.
final class LoginItemController {
  /// Indicates whether macOS currently reports the main application as an enabled Login Item.
  var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  /// Indicates whether macOS requires the user to approve the Login Item in System Settings.
  var requiresApproval: Bool {
    SMAppService.mainApp.status == .requiresApproval
  }

  /// Registers or unregisters the main application for launch at user login.
  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      guard SMAppService.mainApp.status != .enabled else {
        return
      }
      try SMAppService.mainApp.register()
    } else {
      guard SMAppService.mainApp.status != .notRegistered else {
        return
      }
      try SMAppService.mainApp.unregister()
    }
  }

  /// Opens the authoritative Login Items page so the user can inspect or approve registration.
  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
