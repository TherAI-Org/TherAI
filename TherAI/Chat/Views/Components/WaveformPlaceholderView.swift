import SwiftUI

struct WaveformPlaceholderView: View {
    // Live current level (0...1). We snapshot this when spawning each new bar.
    let currentLevel: CGFloat
    
    // Visual parameters
    var barWidth: CGFloat = 2.5
    var barSpacing: CGFloat = 1.5
    var minHeight: CGFloat = 2
    var maxHeight: CGFloat = 30
    var color: Color = Color(red: 0.54, green: 0.32, blue: 0.78) // purple
    var widthGain: CGFloat = 1.2 // added width proportional to level
    var scrollSpeed: CGFloat = 40 // points/sec constant speed (slightly faster spawn cadence)

    // Internal state: ring buffer of frozen bar heights
    @State private var bars: [CGFloat] = []
    @State private var phaseOffset: CGFloat = 0
    @State private var distanceAccumulator: CGFloat = 0
    @State private var lastTick: TimeInterval = 0
    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let unit = barWidth + barSpacing
            // Fractional offset for smooth movement between bar spawns
            let offset = phaseOffset.truncatingRemainder(dividingBy: unit)
                // Draw from right to left; newest bar is on the right
            let startIndex = max(0, bars.count - Int(ceil((size.width + unit) / unit)) - 2)
            var x = size.width - offset - unit * CGFloat(bars.count - 1 - startIndex)
            for i in startIndex..<bars.count {
                let v = bars[i]
                // Keep a visible base width, but cap growth so medium is truly medium
                let w = barWidth + (widthGain * (0.5 + 0.5 * v))
                let h = minHeight + (maxHeight - minHeight) * v
                let rect = CGRect(x: x, y: (size.height - h) / 2, width: w, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color))
                x += unit
            }
        }
        .frame(height: maxHeight)
        .onReceive(ticker) { now in
            let t = now.timeIntervalSinceReferenceDate
            if lastTick == 0 { lastTick = t; return }
            let dt = CGFloat(t - lastTick)
            lastTick = t
            let unit = barWidth + barSpacing
            let advance = scrollSpeed * dt
            phaseOffset += advance
            distanceAccumulator += advance
            while distanceAccumulator >= unit {
                distanceAccumulator -= unit
                // Snapshot instantaneous level; clamp to ensure true zero on silence
                let clamped = max(0, min(1, currentLevel))
                bars.append(clamped)
                if bars.count > 200 { bars.removeFirst(bars.count - 200) }
            }
        }
        .accessibilityHidden(true)
        .onAppear { bars = [] ; phaseOffset = 0 ; distanceAccumulator = 0 ; lastTick = 0 }
    }
}

#Preview {
    WaveformPlaceholderView(currentLevel: 0.5)
        .padding()
}


