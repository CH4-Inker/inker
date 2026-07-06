# Interactive Speaker — watchOS + ESP32

A **standalone Apple Watch app** that plays 4 local songs and streams them to an
**ESP32 Bluetooth speaker**, controlled by on-screen buttons, motion gestures,
and the system Double Tap — all with haptic confirmation.

No iPhone at runtime, no Wi-Fi, no internet. Just the watch and the ESP32 over
Bluetooth.

---

## How it works (architecture)

- **Audio** streams from the watch to the ESP32 over **Bluetooth Classic A2DP**
  (the same profile any BT speaker uses). The watch plays its own local files;
  once the ESP32 is the active Bluetooth output, audio routes there automatically.
- **Controls** (gestures + buttons) run entirely on the watch and act on the
  watch's own player, so there's nothing to send to the ESP32 for playback.
- The ESP32 is, for now, purely a speaker. Its playback-state callbacks are
  where the **LED face** will hook in later (not built yet).

---

## Controls

### Buttons (always available)
Previous · Play/Pause · Next, plus Volume Down / Volume Up.

### Motion gestures (toggle on with the "Motion gestures" switch)

| Gesture | Action | Haptic |
|---|---|---|
| Single flick **right** | Next track | click |
| Single flick **left** | Previous track | click |
| Double flick **right** | Volume up | direction-up |
| Double flick **left** | Volume down | direction-down |
| **Shake** | Play / Pause | start / stop |

### System gesture
**Double Tap** (pinch index + thumb twice) → Play/Pause. Requires Apple Watch
**Series 9 / Ultra 2 or later**.

> **Why these gestures?** The watch can only sense whole-wrist motion
> (accelerometer + gyroscope) — there is **no finger tracking** available to
> third-party apps, and real pinch/clench recognition is not exposed by watchOS.
> Flicks (sharp yaw rotation) and shake (repeated linear acceleration) are the
> reliable, distinguishable motions available. Play/Pause additionally uses the
> one official hands-free hook Apple provides: Double Tap.

**Gesture timing note:** a *single* flick fires only after a short wait
(`doubleWindow`, ~0.45s) so it can rule out a second flick — the same tradeoff a
mouse double-click has. This is expected, not a bug.

---

## Part 1 — watchOS app

### Requirements
- Xcode 16+ (watchOS 11+ SDK; developed against watchOS 26).
- **A real Apple Watch** for testing — motion gestures and Bluetooth audio do
  **not** work in the Simulator.
- Apple Watch **Series 9 / Ultra 2+** for Double Tap (everything else works on
  older watches).
- A paired iPhone is needed **only to install** the app the first time.

### Setup

1. **Create the project**: Xcode → new *watchOS* → *App* (standalone).
2. **Add the source files** from `watchapp/`:
   - `InteractiveSpeakerApp.swift`
   - `PlayerModel.swift`
   - `MotionGestureManager.swift`
   - `ContentView.swift`
3. **Add 4 audio files** named `song1.mp3 … song4.mp3` to the watch target
   (drag into the Project Navigator → check **Copy items if needed** and tick
   the **Watch App target** under *Add to targets*). Verify each file's
   **Target Membership** in the File Inspector. Edit `trackTitles` in
   `PlayerModel.swift` for display names.
4. **Info settings** (target → Info tab):
   - Add `NSMotionUsageDescription` = "Used for wrist gesture controls."
   - Background Modes → enable **Audio** (keeps playback alive with screen off).
5. **Fix the Watch-only identity** (if you hit the
   `WKCompanionAppBundleIdentifier` build error): in the target's Info,
   **remove** any `WKCompanionAppBundleIdentifier` key, and add:
   ```xml
   <key>WKApplication</key>
   <true/>
   <key>WKWatchOnly</key>
   <true/>
   ```
   Then Product → Clean Build Folder (⇧⌘K) and rebuild.
6. **Run** to a real watch.

### Using it
- Buttons work immediately.
- Flip **Motion gestures** ON to arm flick/shake control (you'll feel a "start"
  haptic and an on-screen legend appears). Turn it OFF to avoid accidental
  triggers while walking, etc.
- Double Tap → play/pause.

### Tuning the gestures — top of `MotionGestureManager.swift`
| Constant | Meaning | If gestures… |
|---|---|---|
| `flickThreshold` (3.5) | yaw speed to count as a flick | missed → lower; too easy → raise |
| `doubleWindow` (0.45) | max gap for a "double" flick | doubles missed → raise; single too slow → lower |
| `shakeThreshold` (2.2) | peak accel for a shake | hard to shake → lower; false play/pause → raise |
| `shakePeaksNeeded` (3) | shakes required in window | same as above |
| `flickRefractory` (0.20) | lockout after each flick edge | one flick counts twice → raise |

Watch the `🖐️ [Gesture]` console logs — they print the actual `yawRate` values
so you can tune against real numbers instead of guessing.

---

## Part 2 — ESP32 speaker

### Requirements
- **Original ESP32 (WROOM / WROVER)** — needs Classic Bluetooth for A2DP.
  **ESP32-S3 / C3 / C6 are BLE-only and will NOT work.**
- An I2S DAC/amp (**MAX98357A** or **PCM5102**) + a small speaker.
- Arduino IDE with the **ESP32 board package ≥ 3.0.0** (Boards Manager →
  "esp32" by Espressif Systems).
- **One** library: **ESP32-A2DP** by pschatzmann (Library Manager).
  - *AudioTools is NOT required* — the sketch uses `ESP_I2S.h`, which is built
    into the ESP32 board package. This avoids library version mismatches.

### Setup
1. Wire the DAC to the pins in `esp32_a2dp_speaker.ino`:
   `BCLK = 5`, `WS/LRC = 25`, `DATA/DIN = 26` (change to match your board).
2. Tools → Board → select your ESP32 (e.g. "ESP32 Dev Module").
3. Tools → Partition Scheme → a BT-capable scheme (e.g. **Huge APP**).
4. Flash `esp32/esp32_a2dp_speaker.ino`.
5. On the watch: Settings → Bluetooth → pair **"Interactive Speaker"**.
   Once connected, app audio streams to it automatically.

---

## Debugging

Both sides log verbosely so you can pinpoint any failure.

### ESP32 — Serial Monitor @ 115200 baud
Key lines to watch, in order:
1. `[I2S] Initialized OK.` — DAC pins set up.
2. `[BT] Connection state -> CONNECTED` — the watch paired.
3. `[BT] Audio state -> STARTED (playing)` — playback began.
4. The 2-second heartbeat — **your proof audio is flowing**:
   ```
   [STATUS] conn=CONNECTED | audio=PLAYING | data packets last 2s = 340 (audio is flowing!)
   ```
   - **packets > 0** → Bluetooth audio is arriving. If you still hear nothing,
     the problem is DAC/speaker **wiring**, not Bluetooth.
   - **packets = 0** while playing → the problem is on the **connection/watch**
     side.

### watchOS — Xcode console (tagged logs)
- `🎵 [Player]` — loading, play/pause, and errors like `❌ MISSING FILE`.
- `🎚️ route` — **where audio is going.** Want to see
  `route [play] -> 'Interactive Speaker' ✅ Bluetooth`. If it says
  `⚠️ NOT bluetooth`, the watch is playing to itself, not the ESP32.
- `🖐️ [Gesture]` — every detected flick/shake with its measured values.

### watchOS — on-screen debug panel (no tether needed)
At the bottom of the app screen:
- Colored dot + output name: **green = Bluetooth (ESP32)**, **orange = watch's
  own output**.
- The last event (e.g. "▶️ playing Track One → Interactive Speaker").

### Haptics as a debug signal
Every gesture-triggered action buzzes the moment it's recognised. **Feel a
buzz → the gesture registered.** No buzz → it didn't cross the threshold. This
lets you test sensitivity by feel, without looking at the screen.

### Quick end-to-end check
1. Flash ESP32, open Serial Monitor → boot lines + "A2DP sink started."
2. Pair "Interactive Speaker" on the watch → ESP32 prints `CONNECTED`.
3. Run the watch app, press Play → watch dot **green**, console route = ESP32.
4. ESP32 `[STATUS]` shows **data packets > 0** → working end to end.

---

## Known limitations
- **No finger tracking.** Apple Watch senses whole-wrist motion only; individual
  finger movement and true pinch/clench are not available to apps.
- **Simulator can't test the core.** Motion and Bluetooth audio require a real
  watch.
- **ESP32 chip matters.** A2DP needs Classic Bluetooth — original ESP32 only.
- **Single flick has a built-in delay** (see gesture timing note).
- **Gesture thresholds are personal** — expect to tune them to your wrist.

---

## What's next (not in this build)
- **LED face animation** over a separate BLE link: the watch sends face-state
  commands, the ESP32 renders the animation. The ESP32 sketch already has the
  `audio_state_changed()` hook where playing/idle states can drive the LEDs;
  the watch app would add a `CBCentralManager` to send face-state bytes. Say the
  word to add this layer.

## File map
```
InteractiveSpeaker/
├── README.md
├── watchapp/
│   ├── InteractiveSpeakerApp.swift   app entry point
│   ├── PlayerModel.swift             playlist, playback, volume, route + haptics + logs
│   ├── MotionGestureManager.swift    flick/shake detection engine
│   └── ContentView.swift             UI: buttons, legend, debug panel
└── esp32/
    └── esp32_a2dp_speaker.ino        A2DP Bluetooth speaker sink (debug build)
```
