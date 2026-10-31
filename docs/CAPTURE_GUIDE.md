# Capture guide: learning the InvantiMobility protocol

Goal: produce three things we can decode together.

1. A GATT table (services, characteristics, properties) from ScooterScope or nRF Connect.
2. A Bluetooth packet log of the official Android app doing every action, with a written timeline.
3. The decompiled official Android app, so command encoding can be read instead of guessed.

Facts we know so far:

- Scooter: 5TH WHEEL V40 Pro, model ES14 (retail model number ES14FW04US).
- Official app: InvantiMobility (App Store id 1609751725), formerly branded 5th Wheel.
- Android package name: `com.fivewheelcycling`.

## Part A: GATT table (10 minutes, iPhone or Android)

Option 1, ScooterScope: connect, then export the log. The INFO rows at the top list every service and characteristic.

Option 2, nRF Connect (free, Android and iPhone): scan, connect to the scooter, expand every service, and screenshot each one. This also shows descriptor values and the advertised name.

## Part B: Packet log on Android (30 minutes)

You need: an Android phone, the InvantiMobility app installed on it, a USB cable, and `adb` on the Mac (`brew install android-platform-tools`).

1. On the Android phone enable Developer options (Settings > About phone > tap Build number 7 times).
2. Developer options > Enable Bluetooth HCI snoop log > Enabled. Then turn Bluetooth off and on again so logging starts.
3. Open a notes app and keep a timeline. Write the clock time before each action, for example `14:02:10 lock`.
4. Open InvantiMobility and connect to the scooter. Then do each of these, one at a time, with about 10 seconds of quiet between them:
   - Lock
   - Unlock
   - Each speed mode, in order, then back to the first
   - Headlight on, headlight off
   - Any lighting effect or colour setting the app offers
   - Cruise control on and off (if offered)
   - Zero start or kick start toggle (if offered)
   - Open any settings or info screen the app has (odometer, firmware, battery details)
   - With the scooter on a stand: press the throttle for 3 seconds, then brake
   - Leave it idle for 30 seconds so we get a clean telemetry sample
5. Close the app. On the Mac:

```sh
adb devices                       # phone should appear; accept the USB debugging prompt on the phone
adb bugreport scooter-bugreport.zip
```

6. Unzip it. The log is at `FS/data/misc/bluetooth/logs/btsnoop_hci.log` (path varies a little by phone brand; search the zip for `btsnoop`). If the bugreport has no btsnoop file, on some phones Developer options has a "Bluetooth HCI snoop log" share button instead, or the file is at `/sdcard/btsnoop_hci.log`.
7. Put `btsnoop_hci.log` and your timeline into `docs/captures/<date>/` in this repo. Open it in Wireshark with the display filter `btatt` to eyeball it yourself: Write Request and Handle Value Notification rows are the interesting ones.

## Part C: Pull and decompile the Android app (15 minutes)

```sh
adb shell pm path com.fivewheelcycling
# prints something like package:/data/app/~~abc/com.fivewheelcycling-xyz/base.apk
adb pull /data/app/~~abc/com.fivewheelcycling-xyz/base.apk invantimobility.apk
brew install jadx
jadx -d invantimobility-src invantimobility.apk
```

Then grep the output for the strings that always appear in scooter apps:

```sh
cd invantimobility-src
grep -ril "writeCharacteristic\|setCharacteristicNotification" . | head
grep -ri "ffe1\|ffe0\|fff1\|6e400002\|0000ffe" --include=*.java . | head
grep -ril "lock\|speedMode\|cruise\|headlight" --include=*.java . | head
```

Do not commit the APK or the decompiled source to this repo, they are INVANTI's copyright. Keep them local and share only the specific functions we need, pasted into `docs/PROTOCOL.md`.

If the app turns out to be a Flutter or React Native app, the logic lives in `assets/flutter_assets` or `assets/index.android.bundle` instead of Java; note that and we adjust.

## Part D: What I do with it

- Match each Write Request in the packet log to a timeline entry to get the command bytes.
- Find the frame layout (header bytes, length, command id, payload, checksum) from the decompiled encoder.
- Match notification bytes to known states (battery percentage shown on the dash, speed at idle versus moving).
- Record everything in `docs/PROTOCOL.md`, then implement a `ScooterProtocol` type in the app for Phase 2.
