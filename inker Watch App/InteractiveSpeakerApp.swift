import SwiftUI

// MARK: - App entry point
//
// Target: watchOS 11+ (tested against watchOS 26).
// Double Tap gesture requires Apple Watch Series 9 / Ultra 2 or later.
//
// The audio you play here is routed to the ESP32 automatically once the ESP32
// is paired as a Bluetooth (A2DP) speaker and is the active audio output.
// You do NOT do anything special in code for that routing — iOS/watchOS sends
// AVAudioSession `.playback` audio to the connected A2DP device on its own.

@main
struct InteractiveSpeakerApp: App {
    // One shared model for the whole app.
    @StateObject private var player = PlayerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
        }
    }
}
