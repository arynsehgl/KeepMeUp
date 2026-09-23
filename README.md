# KeepMeUp

KeepMeUp is a private-by-design macOS menu-bar utility that prevents idle system sleep while allowing the display to lock or turn off. Optional toggles can prevent display sleep or maintain computer activity with an explicitly authorized pointer pulse.

## Features

- Starts an **Until Turned Off** awake session whenever the app launches.
- Offers 30-minute, 1-hour, 2-hour, and indefinite sessions.
- Uses 30 minutes as the default when a stopped session is manually enabled.
- Optionally prevents display sleep and remembers that preference across launches.
- Optionally maintains activity after about four minutes without genuine input and remembers that preference after consent.
- Works on battery or external power while the laptop lid remains open.
- Requests consent before registering itself as a macOS Login Item.
- Sends one notification when a timed session ends.
- Checks GitHub Releases at launch and on demand, then leaves installation manual.
- Contains no analytics, telemetry, crash reporting, credentials, or app-specific integrations.

Maintain Activity is off by default. When explicitly enabled, it posts a one-pixel pointer move and immediately restores the original position. It never clicks or types, and it pauses when the macOS user session is inactive or the display is asleep.

## Requirements

- macOS 13 Ventura or newer
- Apple silicon or Intel Mac
- An open laptop lid; ordinary software assertions do not override closed-lid hardware policy
- macOS Accessibility permission only when Maintain Activity is enabled

macOS may still sleep during a low-power or thermal emergency, after an explicit Sleep command, during shutdown, or for other system-enforced reasons.

## Install an unsigned release

KeepMeUp does not currently have an Apple Developer ID certificate, so GitHub builds are ad-hoc signed rather than Apple-notarized.

1. Download the DMG and matching `.sha256` file from the latest GitHub Release.
2. Optionally verify it with `shasum -a 256 -c KeepMeUp-0.2.0.dmg.sha256`.
3. Open the DMG and drag **KeepMeUp.app** into **Applications**.
4. Try to open KeepMeUp once.
5. If macOS blocks it, open **System Settings → Privacy & Security**, scroll to Security, and select **Open Anyway** for KeepMeUp.
6. Confirm **Open** in the final macOS prompt.

Only override Gatekeeper after verifying that the download came from this repository and that its checksum matches the release.

## Usage

Click the KeepMeUp icon in the menu bar:

- **Keep Mac Awake** starts or stops a session.
- **Duration** replaces the current duration and restarts its countdown.
- **Maintain Activity** enables or disables the consent-based pointer pulse.
- **Prevent Display Sleep** controls the optional display assertion.
- **Start at Login** changes the native macOS Login Item registration.
- **Open Login Items Settings…** opens the authoritative system page.
- **Check for Updates…** queries the public GitHub Releases API.
- **Quit KeepMeUp** releases all assertions immediately.

When a timer expires, KeepMeUp remains in the menu bar but turns sleep prevention off. The next application launch always starts a fresh **Until Turned Off** session.

## Maintain Activity and Accessibility

KeepMeUp explains Maintain Activity before its first activation and asks macOS for post-event permission only after consent. If authorization is still required, use **Open Accessibility Settings…** from the menu and enable KeepMeUp under **Privacy & Security → Accessibility**.

The activity scheduler checks the elapsed time since the last input event and reads the current pointer position only long enough to restore it. It does not inspect, record, or transmit keys, clicks, application names, window contents, messages, or pointer history. After about four idle minutes, it posts a one-pixel pointer move and an immediate return. A held mouse button suppresses the pulse so drag operations are not disturbed.

Activity signals generally keep the display awake. KeepMeUp does not bypass the lock screen; generated activity pauses when macOS reports an inactive user session or sleeping display. Only enable activity maintenance where it is appropriate and permitted.

## Privacy and network access

All sleep, timer, and activity behavior is local. KeepMeUp makes one unauthenticated request to GitHub's public Releases API at launch and whenever **Check for Updates…** is selected. It does not automatically download or install updates and sends no usage information.

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

## License

KeepMeUp is released under the [MIT License](LICENSE).
