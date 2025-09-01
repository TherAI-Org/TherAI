import SwiftUI

struct ProfileViewWithMenu: View {
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar with Hamburger Menu
            CustomNavigationBar(title: "Profile")
            
            Divider()
            
            // Profile Content
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
        }
    }
}

#Preview {
    ProfileViewWithMenu()
        .environmentObject(SlideOutSidebarViewModel())
}
