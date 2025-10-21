import SwiftUI

struct TypingIndicatorView: View {

    @State private var isVisible: Bool = false
    @State private var animate: Bool = false

    let showAfter: Double

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animate ? 1.0 : 0.6)
                    .opacity(0.85)
                    .animation(
                        .easeInOut(duration: 0.85)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: animate
                    )
            }
        }
        .onAppear {
            if showAfter <= 0 {
                isVisible = true
                animate = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + showAfter) {
                    isVisible = true
                    animate = true
                }
            }
        }
        .opacity(isVisible ? 1 : 0)
    }
}

#Preview {
    VStack(alignment: .leading) {
        TypingIndicatorView(showAfter: 0)
    }
    .padding()
}


