# ScooterScope

A homemade iPhone app for the 5TH WHEEL V40 Pro (model ES14, sold by INVANTI). The official
app is InvantiMobility, which only talks to the scooter over Bluetooth Low Energy (BLE). Nobody
has published its protocol, so this project is built in phases:

| Phase | Goal | Status |
| --- | --- | --- |
| 1 | Protocol discovery. An app that connects, lists every GATT characteristic, subscribes to all notifications and logs raw bytes with timestamps and markers. Plus a capture guide for the Android packet log and the decompiled official app. | Built, needs on-device testing |
| 2 | Live dashboard (speed, battery, range), lock and unlock, find my scooter. | Not started |
| 3 | Ride logging with maps, charge history, speed modes and other settings. | Not started |

Folders:

- `ScooterScope/` is the iOS app. `project.yml` is the XcodeGen spec that produces the Xcode project.
- `docs/CAPTURE_GUIDE.md` is the step-by-step procedure for capturing the official app's traffic.
- `docs/PROTOCOL.md` is the living notes file where decoded frames, telemetry and commands are recorded.

## Mac setup (one time)

1. Install Xcode from the Mac App Store, open it once, and accept the licence. On first run choose the iOS platform when asked.
2. Install Homebrew from https://brew.sh if you do not have it.
3. In Terminal:

```sh
cd ScooterScope
make setup      # brew install xcodegen
make open       # generates ScooterScope.xcodeproj and opens it
```

4. In Xcode, select the ScooterScope target, open Signing & Capabilities, tick Automatically manage signing and pick your personal team (your Apple ID). To make that stick across regenerations, paste your Team ID into `DEVELOPMENT_TEAM` in `project.yml`.
5. Plug in your iPhone, pick it as the run destination, press Run. The first time, on the phone go to Settings > General > VPN & Device Management and trust your developer certificate.

A free Apple ID installs apps that expire after 7 days and need a re-run from Xcode. A paid developer account lifts that limit.

## Using the Phase 1 app

1. Turn the scooter on, open ScooterScope, tap Scan. The scooter usually shows up with a name containing the model or a vendor string. Look for a strong signal (green dBm).
2. Tap it. The app connects and lists every service and characteristic with its properties.
3. Tap "Subscribe to all notifications". Anything the scooter pushes now appears in the Log, newest first.
4. Use the flag button to drop a marker before you do something: throttle, brake, lock in the official app, and so on. Markers show as yellow rows so the bytes around them can be matched to the action.
5. Log > Actions > Export writes a `.txt` and a `.json` file you can AirDrop or save to Files, then share in this repo under `docs/captures/`.

Important limitation: a BLE peripheral accepts one connection at a time, so while ScooterScope is connected the official app cannot be. ScooterScope alone captures what the scooter broadcasts (telemetry). To learn the commands the app sends (lock, mode, lights), follow `docs/CAPTURE_GUIDE.md` on an Android phone.

## Safety

The Write screen sends arbitrary bytes to the scooter. Only send frames you have seen the official app send or that you understand from the decompiled app. Test writes with the scooter on a stand, wheel off the ground.
