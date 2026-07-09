# 📝 Tech Report — InKer

[◉°] ━━━━━━━⚙️━━━━━━━━━ Team Blackout ━━━━━━━━━⚙️━━━━━━ [°◉]

## 👥 1. Present your team
We are the **BlackOut** team, combining hardware, software, and IoT development to turn our ideas into reality:
*   **@Aarief Satriahutama** — Hardware Developer & Documentation
*   **@Yoram** — Software Developer
*   **@Vito** — IoT Developer

---

## 🔍 2. Starting Assumption

Before diving into development, we defined our core challenge framing based on the Challenge-Based Learning (CBL) framework:

| 🎯 Initial Challenge Response | 🎯 Initial Refined Challenge |
| :---: | :---: |
| ![Initial Challenge Response](docs/inital%20challenge%20response.png) | ![Initial Refined Challenge](docs/initial%20refined%20challenge.png) |
| *Figure 1: Our initial response to the challenge framing.* | *Figure 2: Our refined challenge direction.* |

Following this framing, we established our starting software and hardware assumptions:

### 💻 1. Software Related
**We assumed we would end up using:**
*   **Xcode**: For watchOS app development.
*   **Apple Watch**: As the primary user interface and runtime host.

**Why:**
All software development for watchOS requires Xcode and native compilation to target the Apple Watch device family.

**Initial Architecture & Flow:**
To guide our initial software structure, we designed this baseline flow:
![Initial technical flow chart](docs/Initial%20technical%20flow%20chart.png)
*Figure 3: Initial Technical Flow Chart of communication and logic.*

---

### 🔌 2. Hardware Related
**We assumed we would end up using:**
*   **Arduino IDE & VS Code (PlatformIO)**: For writing and flashing firmware.
*   **Circuit Canvas**: For designing schematics and wiring.
*   **BMS 3S 10A, DC-DC Voltage Step Up, TP4056 Battery Charger, capacitors (470µF & 100µF), carbon film resistors (1/2 W), and ESP32**: For power management, regulation, noise filtering, and microprocessing.
*   **Wokwi**: For simulated animation testing on the OLED screen.

**Why:**
These tools and components are industry standards for prototyping ESP32-based devices and validating circuits before assembly.

**Initial Concept & Hardware Layout:**
Here was our initial physical design sketch and layout planning on the perfboard (prototyping PCB):

| 🎨 Concept Sketch | 🎛️ Initial Perfboard Component Layout |
| :---: | :---: |
| ![Initial Sketch](docs/Initial%20Sketch.jpeg) | ![Initial components and perfboard structure](docs/initial%20components%20we%20though%20we're%20gonna%20use%20and%20the%20structure%20of%20the%20pcb%20bolong.jpeg) |
| *Figure 4: Initial Concept Sketch* | *Figure 5: Layout planning on perfboard (prototyping PCB)* |

And here is the first version of the schematic we designed to connect the ESP32 to the DAC, battery, and peripherals:
![First Version Schematic](docs/First%20Version%20Schematic.jpeg)
*Figure 6: First version schematic diagram.*

---

## 🪵 3. The Exploration Log

### 🔍 What we browsed, and what surprised us:
*   **DAC Module Availability**: We were surprised to find that the `MAX98357A` DAC module was out of stock locally. Ordering it online would take too long, jeopardizing our timeline.
*   **watchOS Gesture Limitations**: We discovered that Apple restricts third-party access to the system's "double pinch" (pitch) and "clench" AssistiveTouch gestures. We had to pivot to custom-designed gestures using the accelerometer/gyroscope.
*   **watchOS Networking Restrictions**: Apple blocks standard low-level TCP/UDP socket connections in standalone watchOS apps. Only high-level protocols via the Foundation framework (`URLSession`) are officially supported.

### 🛠️ What we actually built or tested in code (not just read about):
*   **watchOS to ESP32 Networking**: Built a custom TCP/UDP client on the watch to connect to ESP32's Wi-Fi Access Point. As expected, watchOS blocked it at runtime.
*   **Core Bluetooth**: Switched to Bluetooth and built a working Core Bluetooth service on watchOS to scan and connect with the ESP32.
*   **OLED Screen Animations**: Designed pixel art animations in **Aseprite**, exported them to byte arrays, and successfully simulated them in Wokwi before transferring to physical hardware.
    
    ![Testing OLED animations in Wokwi](docs/Trying%20out%20Animation%20in%20Wokwi%20from%20Array%20that%20was%20first%20made%20in%20Aesprite.png)
    *Figure 7: Simulating character animations in Wokwi with arrays created in Aseprite.*

### 💡 What we discovered that we didn't expect:
*   **The Need for an External DAC**: We discovered that while the ESP32 has an internal DAC, its audio quality is very poor and insufficient for music streaming. To stream clear audio over Bluetooth, an external I2S DAC module (like the `MAX98357A`) is essential to convert the digital signal to high-quality analog signals.
*   **Servo Noise and Voltage Spikes**: We discovered that servos pull massive spikes of current when initiating movement, causing the ESP32 to brown out and reset. Adding decoupling capacitors (100µF and 470µF) was necessary to stabilize the power rail since we are not using a dedicated servo driver board.

---

## ♻️ 4. What We Tried and Dropped

### 🌐 1. Network framework
*   **We considered**: Using the native low-level Network framework (TCP/UDP) to transmit controls directly from the watch to the ESP32.
*   **We dropped it because**: watchOS limits low-level sockets. Apple enforces this sandbox rule on watchOS specifically (it works fine on iOS), blocking local TCP/UDP socket connections (see [Apple Technote 3135](https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos)). We moved to **Core Bluetooth** for control frames and **Bluetooth Classic A2DP** for audio streaming.

### 🖐️ 2. Original User Flow & Direct Finger Gesture Control
*   **We considered**: A direct-gesture control flow using AssistiveTouch (select-then-activate cursor) or detecting fine finger pinches/clenches as outlined in our initial design:
    ![Initial User Flow](docs/initial%20user%20flow.png)
    *Figure 8: Original user flow designed for finer controls.*
*   **We dropped it because**: Apple does not expose individual finger-tracking APIs to third-party developers. Furthermore, AssistiveTouch's cursor navigation model felt clunky and unintuitive. We designed a custom wrist gesture handler using whole-wrist motion instead.

### 🖨️ 3. 3D-Printed Chassis (Physical Body)
*   **We considered**: 3D printing a custom enclosure for the speaker and head display unit.
*   **We dropped it because**: The lead time for 3D printing queues and iteration cycles was too long, and we had a strict deadline. 
*   **Our Pivot**: We chose to manually construct the physical body using **infraboards** (corrugated/fluted plastic sheets). This allowed for immediate, rapid physical iteration and prototyping.

| 🪚 1st Iteration - Left View | 🪚 1st Iteration - Right View |
| :---: | :---: |
| ![1st iteration left body](docs/1st%20iteration%20left%20view%20of%20body.jpeg) | ![1st iteration right body](docs/1st%20iteration%20right%20view%20of%20body.jpeg.jpeg) |
| *Figure 9: Early body shell mockups crafted from infraboards (left)* | *Figure 10: Early body shell mockups crafted from infraboards (right)* |

---

## ⚠️ 5. Real Limitations Hit

### 🧠 The Limits of AI in Hardware Development
As we moved into physical integration with the ESP32 and its modules, we hit a wall with LLM/AI assistance:
*   **Hallucinated Pinouts & Schematics**: AI was unreliable for hardware design, repeatedly suggesting incorrect wiring configurations and pin mappings that could have damaged our components.
*   **Missing API Limitations**: AI models consistently failed to identify the Network framework socket limitations in watchOS, causing us to waste days debugging TCP/UDP connections that Apple blocks by design.
*   **Our Solution**: We stopped relying on AI for hardware and turned to real human-authored articles, official developer documentation, YouTube electronics guides, and direct consultation with external hardware engineer friends who understand electronics.

### ⚡ Battery and Power Distribution Confusions
We struggled with power distribution configurations, trying to run the ESP32, servo, DAC, and amplifier off standard batteries without causing brownouts or overcurrent events.
*   During physical assembly, a wiring mistake led to a short circuit where the positive and negative terminals of the cell got bridged, resulting in a melted battery casing:
    
    ![Melted battery from short circuit](docs/Battery%20implode%20or%20explode%20idk%20bcs%20the%20metal%20and%20plastic%20positive%20and%20negative%20got%20connected.jpeg)
    *Figure 11: Physical battery meltdown caused by short-circuiting during power distribution testing.*
*   To solve this, we redesigned our power path with proper regulators, decoupling capacitors, and a TP4056 charging circuit.

---

## 🎯 6. The Revised Decision

### 🛠️ Final Hardware Iteration (As of July 8th)
*   **Soldering to Perfboard**: After multiple iterations, we finalized our schematic today (July 8th). We are transitioning from breadboard connections to soldering all components onto a permanent **perfboard** (stripboard/prototyping board) for stability.
*   **Revised Schematic**:
    ![Revised Schematic v2](docs/Revised%20v2%20Schematic.jpeg)
    *Figure 12: Finalized version 2 schematic detailing the updated power, ESP32, and DAC connections.*
*   **Head Assembly & Display**: We successfully integrated the OLED display with the main head unit casing:
    ![Side-by-side comparison of head unit with active OLED](docs/side%20by%20side%20comparison%20of%20the%20head%20with%20the%20oled%20display.jpeg)
    *Figure 13: Side-by-side comparison of the physical head assembly with the active OLED display.*

*   **OLED Face Animations**: Each media action is mirrored on the OLED face with a matching pixel-art animation (designed in Aseprite, running live on the physical hardware), giving the device an expressive, eyes-catching character on top of the eyes-free haptic controls:

| ▶️ Play | ⏸️ Pause | 🎵 Music Playing |
| :---: | :---: | :---: |
| ![Play animation](docs/animation/play.gif) | ![Pause animation](docs/animation/pause.gif) | ![Music playing animation](docs/animation/music_playing.gif) |
| *Figure 14: Face animation triggered on Play.* | *Figure 15: Face animation triggered on Pause.* | *Figure 16: Idle/looping animation while music is actively playing.* |

| ⏮️ Previous Track | ⏭️ Next Track |
| :---: | :---: |
| ![Backward/previous track animation](docs/animation/backward.gif) | ![Forward/next track animation](docs/animation/forward.gif) |
| *Figure 17: Face animation triggered on the Previous track control.* | *Figure 18: Face animation triggered on the Next track control.* |

---

### ⌚ Hybrid Gestures & Physical Controls
Instead of direct finger gestures or standard buttons only, we implemented a hybrid control matrix:
1.  **On-Screen Buttons (Always Available)**: Previous track, Play/Pause, Next track, and a Volume slider on the controls page.
2.  **Custom Wrist Gestures (Toggleable via Switch)**:
    *   **Haptic Flick (any direction)** ➔ Triggers **Previous track** (registered with a `click` haptic).
    *   **Wrist Shake** ➔ Triggers **Play / Pause** (registered with a `start/stop` haptic sequence).
    *   *Why either direction for flick?* The watch only senses whole-wrist acceleration/rotation. Flicking in either direction triggers a single reliable action, reducing false positives.
3.  **System Gesture (Double Tap)**:
    *   **Double Tap (pinch index + thumb twice)** ➔ Triggers **Next track**. Uses the native watchOS API. Requires Apple Watch Series 9 / Ultra 2 or later.
4.  **Digital Crown (Physical Dial)**:
    *   **Rotate the Crown** ➔ Adjusts volume up/down, utilizing system haptic detents for a tactile feel.

---

## 📋 App Track Addendum

### About the Frameworks
*Does your use case genuinely need both frameworks working together, or could it work with just your main one?*
*   **Yes**, our use case relies on a coordinated multi-framework pipeline to handle inputs, audio processing, and peripheral communication, with **Core Bluetooth** acting as the core framework connecting the Apple Watch to the IoT speaker:
    1.  **Core Bluetooth**: Our core integration framework. It establishes a BLE connection to send control frames (e.g., `$PLAY#`, `$NEXT#`, volume packets) to the ESP32 to drive display updates and LED states.
    2.  **Core Motion**: Captures accelerometer and gyroscope data to detect wrist movements and translate them into physical media triggers (flicks and shakes).
    3.  **App Intents (Siri Shortcuts)** *(Under Active Development)*: We are currently developing Siri Shortcuts integration using the **App Intents** framework. This will expose playback commands directly to voice control, allowing hands-free shortcuts (e.g. telling Siri to control the speaker).
    4.  **AVFoundation**: Acts as the central player engine, loading local MP3 files, decoding them, and routing audio output via Bluetooth A2DP.
*   **Why they must coexist**: They form an integrated pipeline: **Core Bluetooth** manages the primary control connection to the physical ESP32 companion device, while **Core Motion** and **App Intents** capture the user's input intent (motion gestures and voice shortcuts) to update the playback state, and **AVFoundation** handles the actual local audio playback. A single framework cannot bridge these layers.

### About Accessibility and Localization
*What did you decide to support, what did you decide not to, and why? "We didn't localize" is a fine answer if you can say why, "we didn't think about it" is not.*
*   **Accessibility (Decisions & Trade-offs)**:
    *   *The Gesture Constraint*: We recognized that our custom wrist flick and shake gestures require full wrist mobility and are not accessible to users with motor impairments or tremors.
    *   *Non-Visual Operation (Eyes-Free Haptic UI)*: Since watchOS is a dark-only operating system without a Light Mode option, dark mode is simply a system-wide appearance setting rather than a distinct accessibility choice. Instead, we designed our app from the perspective that **it does not require the user to visually look at the watch screen to control it**. To achieve this, every gesture (flick and shake) and physical/button control triggers distinct, unique haptic feedback vibration patterns (clicks, start/stops, and detents). This allows blind or visually impaired users—as well as active users running or doing sports—to operate the media controls completely eyes-free through tactile haptic confirmation.
    *   *System Integration*: We integrated Apple's native **Double Tap** (pinch) gesture for the "Next track" action, allowing users with compatible watches to leverage Apple's highly optimized, low-effort assistive accessibility hook.
*   **Localization**: We did not localize the app text because the interface relies almost entirely on universal media control iconography (Play/Pause, Fast Forward, Rewind, Speaker icons). The limited text is basic terminology (like song titles) which does not require localization for our current target audience.

### About Privacy
*What data does your app actually need? What happens in your app when the user says no to a permission?*
*   **Motion Data**: The app requires permission to access the Apple Watch's accelerometer and gyroscope data to detect wrist flicks and shake gestures.
*   **Denial Handler**: If the user denies motion permissions, the wrist gesture control feature is disabled. However, the app remains fully functional using the on-screen buttons, the Digital Crown, and native watchOS Double Tap gestures.
