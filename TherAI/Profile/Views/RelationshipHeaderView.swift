import SwiftUI

struct RelationshipHeaderView: View {

    let relationshipHeader: RelationshipHeader

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: -20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)

                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text("M")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.pink.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)

                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.pink, .pink.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text("S")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }
            }

            VStack(spacing: 10) {
                Text("Together since")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                Text(relationshipHeader.relationshipStartMonthYear)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(0.5)
            }

            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    .font(.system(size: 12))

                Text("\(relationshipHeader.relationshipDuration) of love")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.pink.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(.pink.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    // iOS 26+ Liquid Glass effect
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.clear)
                        .glassEffect()
                } else {
                    // Fallback for older iOS versions
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
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
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
        )
    }
}

#Preview {
    RelationshipHeaderView(relationshipHeader: RelationshipHeader(
        firstName: "Michael",
        lastName: "Johnson",
        partnerFirstName: "Sarah",
        partnerLastName: "Smith",
        relationshipStartDate: Date(),
        relationshipDuration: "2 years",
        personalityType: "Analytical"
    ))
    .padding(20)
}
