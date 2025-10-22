import SwiftUI

struct GlassIconButton: View {
    let systemName: String

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                glassContent
            } else {
                fallbackContent
            }
        }
    }

    @ViewBuilder
    private var glassContent: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .frame(width: 34, height: 34)
            .background(
                ZStack {
                    Color.clear.glassEffect(.regular, in: Circle()).opacity(0.80)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.80, green: 0.72, blue: 1.00),
                                    Color(red: 0.67, green: 0.49, blue: 1.00)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.12)
                        .allowsHitTesting(false)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.14),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    @ViewBuilder
    private var fallbackContent: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .frame(width: 34, height: 34)
            .background { Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1)) }
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}


