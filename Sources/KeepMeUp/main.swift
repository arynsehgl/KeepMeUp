import AppKit

// The executable uses AppKit directly so the packaged utility has no window or Dock presence.
let application = NSApplication.shared
let applicationDelegate = ApplicationDelegate()
application.setActivationPolicy(.accessory)
application.delegate = applicationDelegate
application.run()
