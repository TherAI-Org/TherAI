import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let profileData = viewModel.profileData {
                    ZStack {
                        // Beautiful background with light blur pink gradients
                        BackgroundView()
                        
                        ScrollView {
                            VStack(spacing: 20) {
                                // Profile Header Card
                                ProfileHeaderCard(userProfile: profileData.userProfile)
                                
                                // Avatar Selection Card
                                AvatarSelectionCard()
                                
                                // Premium Stats Cards
                                PremiumStatsCards(stats: profileData.profileStats)
                                
                                // Premium Relationship Insights
                                RelationshipInsightsSection()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage) {
                        viewModel.loadProfileData()
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Beautiful Background View
struct BackgroundView: View {
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(.systemGray6),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Floating pink orbs with blur
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

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ProfileView()
}
