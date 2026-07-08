# Tech Report - InKer

## 1. Present your team
We're BlackOut team, and here are the tech members that turn our ideas into reality :
@Aarief Satriahutama - Hardware Developer & Documentation
@Yoram - Software Developer
@Vito - IoT Developer 

[◉°] ━━━━━━━⚙️━━━━━━━━━ Team Blackout ━━━━━━━━━⚙️━━━━━━ [°◉]

## 2. Starting Assumption

1. Software Related
We think we'll end up using:
- XCode for watch app development
- Apple Watch for the app

Because:
All the tools mentioned above is necessary for the development of our project

2. Hardware Related
We think we'll end up using:
- Arduino IDE and VS Code PlatformIO for hardware development 
- Circuit Canvas for Hardware wiring
- BMS 3S 10A, DC-DC Voltage Step Up, Elco Capactifor 470uf and 100uf, TP4056 Battery Charging, Resistor Carbon film1/2 watt, ESP32
- Wokwi for animation testing on the OLED Display

Because:
All the tools mentioned above is necessary for the development of our project

---

## 3. The Exploration Log
- What we browsed, and what surprised us:
    - From our findings we can't find Modul MAX98357A because if we order today it will take a long time
    - It turns out the "pitch" and "clench" gestures we talked about earlier can't be used, guys Apple has locked them. For now, I'm using "wrist flick" and "shake" as alternatives.
    - Apple doesn't allow WatchOS app to use TCP/UDP protocol, only allow the high-level protocol like Foundation Framework (URLSession).
- What we actually built or tested in code (not just read about):
    - Network framework to connect watch with esp32 - doesn't work
    - Bluetooth core framework - work
    Animation
- What we discovered that we didn't expect:
    - To enable music streaming, you need a DAC module to convert the digital signal to analog so it can be processed by the speaker.  The ESP32 has an internal DAC, but it has limitations on the sound quality it produces. To get better sound quality for music streaming, you need an additional external DAC module like the MAX98357A.
    [image]


    - Servos need stable voltage and current, so a capacitor is necessary if we're not using a special servo module. https://www.instructables.com/One-and-Multiple-Servo-Motor-Control-With-ESP32-De/. 

---

## 4. What We Tried and Dropped
We considered:
- The Network framework in watchOS 

We dropped it because:
- Is limited because it involves low-level networking, this applies only to watchOS, not iOS. That is why I’ve been blocked here. https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos. The current solution is to use Bluetooth or move up to a higher-level layer, such as the Foundation framework (URLSession).

---

## 5. Real Limitations Hit
During the exploration, since we touch the physical component like the ESP32 and its modules. We can't use AI to do the work, only suggest us what we can do.
We also have problem when connecting the Apple Device (WatchOS) to the ESP32 with the network framework. after debugging for a few days, we just realized that there is a limitation on WatchOS only when using network framework especially the TCP/UDP protocol. Apple doesn't allow us to use the low-level protocol for WatchOS only. We just know this limitation after search through the Apple documentation which AI missed with this information.
Because of this limitation, we have to change the framework with Core Bluetooth.

---

## 6. The Revised Decision
Final decision:
We use Bluetooth framework

What changed since Section 1, and why:
Network framework

---

## App Track Addendum
About the Frameworks
Does your use case genuinely need both frameworks working together, or could it work with just your main one?
Yes, we need to both framework core bluetooth and watchOS working together because the core bluetooth only the framework to connect the Apple device with the IoT.

About Accessibility and Localization
What did you decide to support, what did you decide not to, and why? "We didn't localize" is a fine answer if you can say why, "we didn't think about it" is not.
We help people control music in an interactive way.

About Privacy
What data does your app actually need? What happens in your app when the user says no to a permission?
Gesture data - when the user says no, the user not be able to control the IoT device
