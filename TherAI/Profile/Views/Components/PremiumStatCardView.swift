// View is nowhere to be used, consider deleting in the future.



import SwiftUI

struct PremiumStatCardView: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    // iOS 26+ Liquid Glass effect
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.clear)
                        .glassEffect()
                } else {
                    // Fallback for older iOS versions
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(.systemBackground).opacity(0.8),
                                            Color(.systemBackground).opacity(0.6)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
        )
    }
}


#Preview {
    HStack(spacing: 12) {
        PremiumStatCardView(title: "Avg Rating", value: "4.8", icon: "star.fill", gradient: [.yellow, .orange])
        PremiumStatCardView(title: "New Sessions", value: "3", icon: "plus", gradient: [.blue, .purple])
    }
    .padding(20)
}


