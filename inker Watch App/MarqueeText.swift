import SwiftUI

/// Single-line text that stays put if it fits, and auto-scrolls end-to-end
/// (like the Music app) when it's wider than the available width.
///
/// Driven by `TimelineView(.animation)` (a per-frame clock) rather than a
/// `repeatForever` animation — the latter is unreliable inside a lazy `List`
/// row, which is exactly where this is used.
struct MarqueeText: View {
    let text: String
    var font: Font = .body
    var speed: CGFloat = 25      // points per second
    var pause: Double = 1.2      // seconds held at each end

    @State private var textWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0

    private var overflow: Bool { textWidth > boxWidth + 1 && boxWidth > 0 }

    var body: some View {
        TimelineView(.animation) { context in
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .background(widthReader { textWidth = $0 })
                .offset(x: offset(at: context.date))
                // Centered while it fits; left-aligned so it scrolls when long.
                .frame(maxWidth: .infinity, alignment: overflow ? .leading : .center)
                .clipped()
                .background(widthReader { boxWidth = $0 })
        }
    }

    private func offset(at date: Date) -> CGFloat {
        let gap = textWidth - boxWidth
        guard gap > 1, boxWidth > 0 else { return 0 }
        let travel = gap + 8
        let travelDur = Double(travel / speed)
        let cycle = 2 * (pause + travelDur)
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)

        if phase < pause {
            return 0                                   // hold at start
        } else if phase < pause + travelDur {
            let p = (phase - pause) / travelDur        // 0→1 scrolling left
            return -travel * CGFloat(p)
        } else if phase < 2 * pause + travelDur {
            return -travel                             // hold at end
        } else {
            let p = (phase - 2 * pause - travelDur) / travelDur  // 1→0 back
            return -travel * CGFloat(1 - p)
        }
    }

    private func widthReader(_ update: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { g in
            Color.clear
                .onAppear { update(g.size.width) }
                .onChange(of: g.size.width) { _, w in update(w) }
        }
    }
}
