// swift-tools-version: 5.9

import PackageDescription

/// Defines the command-line-buildable KeepMeUp application and its testable core module.
let package = Package(
  name: "KeepMeUp",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "KeepMeUp", targets: ["KeepMeUp"])
  ],
  targets: [
    .target(
      name: "KeepMeUpCore"
    ),
    .executableTarget(
      name: "KeepMeUp",
      dependencies: ["KeepMeUpCore"],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("IOKit"),
        .linkedFramework("ServiceManagement"),
        .linkedFramework("UserNotifications"),
      ]
    ),
    .testTarget(
      name: "KeepMeUpCoreTests",
      dependencies: ["KeepMeUpCore"]
    ),
  ]
)
