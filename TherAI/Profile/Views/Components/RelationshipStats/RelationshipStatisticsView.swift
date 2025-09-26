import SwiftUI

struct RelationshipStatisticsView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            }

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
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
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}


#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        RelationshipStatisticsView(title: "Communication", value: "Great", icon: "message.fill", color: .blue)
        RelationshipStatisticsView(title: "Trust Level", value: "Strong", icon: "lock.shield.fill", color: .green)
        RelationshipStatisticsView(title: "Future Goals", value: "Aligned", icon: "target", color: .purple)
        RelationshipStatisticsView(title: "Intimacy", value: "Deep", icon: "heart.fill", color: .pink)
    }
    .padding(20)
}


