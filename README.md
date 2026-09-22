# KeepMeUp

KeepMeUp is a private-by-design macOS menu-bar utility that prevents idle system sleep while allowing the display to lock or turn off. An optional toggle can also prevent display sleep.

## Features

- Starts an **Until Turned Off** awake session whenever the app launches.
- Offers 30-minute, 1-hour, 2-hour, and indefinite sessions.
- Uses 30 minutes as the default when a stopped session is manually enabled.
- Optionally prevents display sleep and remembers that preference across launches.
- Works on battery or external power while the laptop lid remains open.
- Requests consent before registering itself as a macOS Login Item.
- Sends one notification when a timed session ends.
- Checks GitHub Releases at launch and on demand, then leaves installation manual.
- Contains no analytics, telemetry, crash reporting, credentials, or app-specific integrations.

KeepMeUp does not simulate keyboard or mouse activity. It keeps macOS and running applications awake, but it does not guarantee that another application will interpret the user as active.

## Requirements

- macOS 13 Ventura or newer
- Apple silicon or Intel Mac
- An open laptop lid; ordinary software assertions do not override closed-lid hardware policy

macOS may still sleep during a low-power or thermal emergency, after an explicit Sleep command, during shutdown, or for other system-enforced reasons.

## Install an unsigned release

KeepMeUp does not currently have an Apple Developer ID certificate, so GitHub builds are ad-hoc signed rather than Apple-notarized.

1. Download the DMG and matching `.sha256` file from the latest GitHub Release.
2. Optionally verify it with `shasum -a 256 -c KeepMeUp-0.1.0.dmg.sha256`.
3. Open the DMG and drag **KeepMeUp.app** into **Applications**.
4. Try to open KeepMeUp once.
5. If macOS blocks it, open **System Settings → Privacy & Security**, scroll to Security, and select **Open Anyway** for KeepMeUp.
6. Confirm **Open** in the final macOS prompt.

Only override Gatekeeper after verifying that the download came from this repository and that its checksum matches the release.

## Usage

Click the KeepMeUp icon in the menu bar:

- **Keep Mac Awake** starts or stops a session.
- **Duration** replaces the current duration and restarts its countdown.
- **Prevent Display Sleep** controls the optional display assertion.
- **Start at Login** changes the native macOS Login Item registration.
- **Open Login Items Settings…** opens the authoritative system page.
- **Check for Updates…** queries the public GitHub Releases API.
- **Quit KeepMeUp** releases all assertions immediately.

When a timer expires, KeepMeUp remains in the menu bar but turns sleep prevention off. The next application launch always starts a fresh **Until Turned Off** session.

## Privacy and network access

All sleep and timer behavior is local. KeepMeUp makes one unauthenticated request to GitHub's public Releases API at launch and whenever **Check for Updates…** is selected. It does not automatically download or install updates and sends no usage information.

## Build and test

The project uses Swift Package Manager so it can be built with Apple command-line tools:

```bash
swift test
swift run KeepMeUp
```

Create an ad-hoc-signed Universal DMG:

```bash
bash scripts/package_app.sh
```

The generated DMG and checksum appear in `dist/`. The packaging script requires the standard macOS tools `lipo`, `sips`, `iconutil`, `codesign`, and `hdiutil`.

## Roadmap

Version 2 may add an explicit, opt-in activity-presence mode. That mode will be designed separately because it has different permissions, privacy implications, and application behavior from preventing system sleep.

## License

KeepMeUp is released under the [MIT License](LICENSE).
