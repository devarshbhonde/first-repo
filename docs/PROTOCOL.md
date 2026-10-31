# 5TH WHEEL V40 Pro (ES14) BLE protocol notes

Status: nothing decoded yet. This file is filled in as captures arrive. Every claim below should say
where it came from (capture file, decompiled function, or guess).

## Identity

| Item | Value | Source |
| --- | --- | --- |
| Model | 5TH WHEEL V40 Pro, ES14 (ES14FW04US) | Owner, retail listing |
| Official app | InvantiMobility, formerly 5th Wheel | App Store |
| Android package | com.fivewheelcycling | AppBrain listing |
| Advertised BLE name | unknown | |
| Pairing or PIN | unknown | |

## GATT table

Fill from the ScooterScope export or nRF Connect screenshots.

| Service | Characteristic | Properties | Role (guess) |
| --- | --- | --- | --- |
| | | | |

Hypothesis: budget scooter controllers almost always expose one of these. ScooterScope labels them automatically.

- `FFE0` / `FFE1` (HM-10 style serial over BLE, one characteristic for both directions)
- `FFF0` with `FFF1` (notify) and `FFF2` (write)
- Nordic UART `6E400001-...` with `6E400002` (write) and `6E400003` (notify)

## Frame format

Unknown. Typical shapes to test against the capture:

- Header bytes (often `55 AA`, `5A A5`, `AA 55`, or a single `A6`/`3E`)
- Length byte
- Command or register id
- Payload
- Checksum: XOR of all bytes, sum truncated to one byte, or CRC16

## Telemetry (scooter to phone)

| Field | Offset | Size | Unit and scale | Confidence | Source |
| --- | --- | --- | --- | --- | --- |
| Speed | | | | | |
| Battery percent | | | | | |
| Battery voltage | | | | | |
| Odometer | | | | | |
| Trip distance | | | | | |
| Current mode | | | | | |
| Lock state | | | | | |
| Headlight state | | | | | |
| Error code | | | | | |

## Commands (phone to scooter)

| Action | Bytes | Characteristic | Response | Confidence | Source |
| --- | --- | --- | --- | --- | --- |
| Lock | | | | | |
| Unlock | | | | | |
| Speed mode 1 / 2 / 3 | | | | | |
| Headlight on / off | | | | | |
| Lighting effect | | | | | |
| Cruise on / off | | | | | |
| Zero start on / off | | | | | |
| Request status | | | | | |

## Open questions

- Does the scooter require any handshake or authentication after connecting before it will accept commands?
- Does it keep streaming telemetry without being asked, or only after a status request?
- Does it accept more than one central at a time? (Expected: no.)
- Are speed values km/h or mph on the wire, and does the dash unit setting change them?
