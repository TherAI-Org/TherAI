import SwiftUI

struct ExpandableSessionCardView: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(0.7)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.25, dampingFraction: 0.5, blendDuration: 0.1), value: isExpanded)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemBackground),
                                Color(.systemBackground).opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


#Preview {
    HStack(spacing: 12) {
        ExpandableSessionCardView(
            title: "Sessions Resolved",
            value: "18",
            icon: "checkmark.circle.fill",
            gradient: [.green, .green.opacity(0.7)],
            isExpanded: true,
            onTap: {}
        )

        ExpandableSessionCardView(
            title: "Needs Improvement",
            value: "5",
            icon: "exclamationmark.triangle.fill",
            gradient: [.orange, .orange.opacity(0.7)],
            isExpanded: false,
            onTap: {}
        )
    }
    .padding(20)
}


