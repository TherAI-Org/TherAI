import SwiftUI

struct TotalSessionsCardView: View {
    let totalSessions: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Sessions")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text("\(totalSessions)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    // iOS 26+ Liquid Glass effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.clear)
                        .glassEffect()
                } else {
                    // Fallback for older iOS versions
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
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
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}


#Preview {
    TotalSessionsCardView(totalSessions: 24)
        .padding(20)
}


