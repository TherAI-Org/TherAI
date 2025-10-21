import SwiftUI

struct SplashOverlayView: View {
    @Binding var isVisible: Bool

    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            Image(systemName: "infinity")
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.58, blue: 1.00),
                            Color(red: 0.63, green: 0.32, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        scale = 1.06
                    }
                }
        }
        .opacity(opacity)
        .onChange(of: isVisible) { _, visible in
            if visible {
                withAnimation(.easeInOut(duration: 0.2)) { opacity = 1.0 }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) { opacity = 0.0 }
            }
        }
        .onAppear {
            opacity = isVisible ? 1.0 : 0.0
        }
        .accessibilityHidden(true)
    }
}


