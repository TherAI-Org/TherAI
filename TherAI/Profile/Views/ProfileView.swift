import SwiftUI

struct ProfileView: View {
    private let data: ProfileData = ProfileData.load()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Inline header with centered title and trailing close button
            ZStack {
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .offset(x: -10)
                    .accessibilityLabel("Close")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            Group {
                ZStack {
                    BackgroundView()

                    ScrollView {
                        VStack(spacing: 20) {
                            // Profile Header Card
                            RelationshipHeaderView(relationshipHeader: data.relationshipHeader)
                            
                            // Avatar Selection
                            AvatarSelectionView()
                            
                            // Premium Stats Cards
                            PremiumStatsCardsView(viewModel: PremiumStatsViewModel(), stats: data.profileStats)
                            
                            // Premium Relationship Insights
                            RelationshipInsightsSectionView()
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

struct BackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemGray6),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.pink.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(x: 150, y: 100)
        }
    }
}

#Preview {
    ProfileView()
}
