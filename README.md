# Interactive Speaker — watchOS + ESP32

A **standalone Apple Watch app** that plays 4 local songs and streams them to an
**ESP32 Bluetooth speaker**, controlled by on-screen buttons, motion gestures,
the system Double Tap, and the Digital Crown — all with haptic confirmation.

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

## Screens
Two pages, swipe left/right between them (`TabView` paging), both sharing a
top bar (playlist button + a "Gesture ON" badge when motion gestures are
armed). No app clock — watchOS shows its own in the status bar:

- **Now Playing** — title/artist, a seekable progress bar (tap to jump within
  the track), and a card showing the last gesture that drove playback (tap it
  to open the **Gestures** guide).
- **Controls** — circular Previous/Play-Pause/Next buttons, a volume bar
  flanked by speaker icons, and the **Motion gesture** toggle.

From either page, tap the top-left icon to open **My Playlist** — tap a track
to play it, tap the currently-playing track to toggle play/pause.

## Controls

### Buttons (always available)
Previous · Play/Pause · Next, plus Volume Down / Volume Up (on the Controls page).

### Motion gestures (toggle on with the "Motion gestures" switch)

| Gesture | Action | Haptic |
|---|---|---|
| Flick (either direction) | Previous track | click |
| **Shake** | Play / Pause | start / stop |

### System gesture
**Double Tap** (pinch index + thumb twice) → Next track. Requires Apple Watch
**Series 9 / Ultra 2 or later**.

### Digital Crown
Rotate the Crown → Volume up/down, with the system's built-in haptic detents.

> **Why this mix?** The watch can only sense whole-wrist motion
> (accelerometer + gyroscope) — there is **no finger tracking** available to
> third-party apps, and AssistiveTouch's cursor-based select-then-activate
> model wasn't wanted here. A sharp wrist flick (either direction — no need
> to distinguish, since it only drives one action) reliably triggers
> Previous, and shake reliably triggers Play/Pause. Next uses the one
> official hands-free hook Apple provides directly to apps: Double Tap.
> Volume uses the Crown since it's a dedicated physical control with no
> ambiguity or false-trigger risk at all.

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
   - `TopBar.swift`
   - `ThinBar.swift`
   - `NowPlayingView.swift`
   - `ControlsView.swift`
   - `PlaylistView.swift`
   - `GestureGuideView.swift`
3. **Add 4 audio files** named `song1.mp3 … song4.mp3` to the watch target
   (drag into the Project Navigator → check **Copy items if needed** and tick
   the **Watch App target** under *Add to targets*). Verify each file's
   **Target Membership** in the File Inspector. Edit `trackTitles` and
   `trackArtists` in `PlayerModel.swift` for display names.
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
- Buttons work immediately (Controls page).
- Flip **Motion gesture** ON (Controls page) to arm flick/shake control
  (you'll feel a "start" haptic, and the top bar shows a "Gesture ON" badge).
  Turn it OFF to avoid accidental triggers while walking, etc.
- Double Tap → next. Rotate the Digital Crown → volume.
- Tap the last-gesture card on the Now Playing page to see the full gesture
  list (Gestures screen).

### Tuning the gestures — top of `MotionGestureManager.swift`
| Constant | Meaning | If gestures… |
|---|---|---|
| `flickThreshold` (12.0) | pitch (tilt) speed to count as a flick | missed → lower; fires from normal hand movement → raise |
| `flickReset` (4.0) | pitch speed must fall below this before another flick can fire | one rotation fires more than once → raise (closer to `flickThreshold`) |
| `flickRefractory` (0.35) | minimum time between flicks | one flick counts twice → raise |
| `shakeThreshold` (2.2) | peak accel for a shake | hard to shake → lower; false play/pause → raise |
| `shakePeaksNeeded` (3) | shakes required in window | same as above |

**How to tune `flickThreshold` to your actual wrist:** every time your hand
settles after moving, the console logs a line like
`hand movement settled, peak rotationRate.x = 4.31 rad/s (threshold=8.00)` —
even for movements that *don't* fire. Move your hand normally a few times and
note the peak values, then do a real fast flick and note that peak. Set
`flickThreshold` somewhere between the two (closer to the fast-flick number)
so casual movement never crosses it but a deliberate flick reliably does.

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

### watchOS — on-screen debug panel
Dropped from the redesigned UI (Now Playing / Controls / Playlist / Gestures
screens have no room for it) — `outputRouteName`, `isBluetoothOutput`, and
`lastEvent` are still tracked in `PlayerModel` and printed to the Xcode
console (`🎵 [Player]` / `🎚️ route`), just no longer shown on-watch. Say the
word if you want a debug page added back (e.g. a 3rd swipe page).

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
- **Simulator can't test the core.** Motion, Digital Crown, and Bluetooth audio
  require a real watch (Crown rotation does work in Simulator via the "..."
  menu, but treat that as unverified until tested on-device).
- **ESP32 chip matters.** A2DP needs Classic Bluetooth — original ESP32 only.
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
│   ├── PlayerModel.swift             playlist, playback, volume, progress, route + haptics + logs
│   ├── MotionGestureManager.swift    flick/shake detection engine (previous/play-pause)
│   ├── ContentView.swift             paging container: Crown + Double Tap wiring, gesture callbacks
│   ├── TopBar.swift                  shared header: playlist button, Gesture ON badge
│   ├── ThinBar.swift                 thin rounded progress/volume bar (seekable variant)
│   ├── NowPlayingView.swift          page 1: title/artist/seek bar, last-gesture card
│   ├── ControlsView.swift            page 2: transport, volume, Motion gesture toggle
│   ├── PlaylistView.swift            track list, tap to play/pause
│   └── GestureGuideView.swift        static list of all gesture mappings
└── esp32/
    └── esp32_a2dp_speaker.ino        A2DP Bluetooth speaker sink (debug build)
```
