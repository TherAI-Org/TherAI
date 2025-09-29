import SwiftUI

struct RelationshipHeaderView: View {

    let relationshipHeader: RelationshipHeader
    @EnvironmentObject private var linkVM: LinkViewModel
    @EnvironmentObject private var sessionsVM: ChatSessionsViewModel

    private var linkedMonthYear: String? {
        guard let date = linkVM.linkedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: -20) {
                avatarCircle(url: sessionsVM.myAvatarURL, fallback: "Me", size: 70)
                avatarCircle(url: sessionsVM.partnerAvatarURL, fallback: "X", size: 70)
            }

            if case .linked = linkVM.state, let monthYear = linkedMonthYear {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .font(.system(size: 14, weight: .medium))
                    Text("Together since \(monthYear)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .tracking(0.5)
                }
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
                if colorScheme == .light {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                } else {
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
                                                Color(.systemGray6).opacity(0.8),
                                                Color(.systemGray6).opacity(0.6)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                    }
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
        )
    }
}

private extension RelationshipHeaderView {
    @ViewBuilder
    func avatarCircle(url: String?, fallback: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.58, blue: 1.00),
                            Color(red: 0.63, green: 0.32, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                )

            if let urlStr = url, let u = URL(string: urlStr) {
                AsyncImage(url: u) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Text(fallback)
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Text(fallback)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
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
