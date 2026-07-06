import SwiftUI

/// Pushed from the Now Playing screen's gesture card. Lists every gesture the
/// app responds to — keep this in sync with the actual wiring in
/// ContentView/MotionGestureManager if the mapping ever changes.
struct GestureGuideView: View {
    private struct Entry: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let action: String
    }

    private let entries = [
        Entry(icon: "hand.pinch", label: "Double Tap", action: "Next track"),
        Entry(icon: "hand.draw.fill", label: "Flick", action: "Previous track"),
        Entry(icon: "waveform.path", label: "Shake", action: "Play / Pause"),
        Entry(icon: "digitalcrown.arrow.counterclockwise", label: "Digital Crown", action: "Volume"),
    ]

    var body: some View {
        List(entries) { entry in
            HStack(spacing: 10) {
                Image(systemName: entry.icon)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.label).bold()
                    Text(entry.action)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Gestures")
    }
}

#Preview {
    NavigationStack { GestureGuideView() }
}
