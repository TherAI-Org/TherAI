import SwiftUI

struct ProfileView: View {
    private let data: ProfileData = ProfileData.load()

    @Environment(\.dismiss) private var dismiss
    @State private var showingAvatarSelection = false

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

                            // Edit Avatars Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingAvatarSelection = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "person.2.circle")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Edit Avatars")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(
                                            LinearGradient(
                                                colors: [.pink, .blue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            }

                            // Premium Stats Cards
                            PremiumStatsCardsView(viewModel: PremiumStatsViewModel(), stats: data.profileStats)

                            // Premium Relationship Insights
                            RelationshipInsightsSectionView()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .overlay(
            showingAvatarSelection ?
            ZStack {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingAvatarSelection = false
                        }
                    }

                // Avatar selection card
                AvatarSelectionView(isPresented: $showingAvatarSelection)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
            }
            .animation(.easeInOut(duration: 0.3), value: showingAvatarSelection)
            : nil
        )
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
