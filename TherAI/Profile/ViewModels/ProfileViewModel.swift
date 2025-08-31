import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profileData: ProfileData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        loadProfileData()
    }
    
    func loadProfileData() {
        isLoading = true
        errorMessage = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.profileData = ProfileData(
                userProfile: UserProfile(
                    firstName: "Michael",
                    lastName: "Johnson",
                    partnerFirstName: "Sarah",
                    partnerLastName: "Smith",
                    relationshipStartDate: Date(),
                    relationshipDuration: "2 years",
                    personalityType: "Analytical"
                ),
                profileStats: ProfileStats(
                    totalSessions: 24,
                    newSessions: 0,
                    averageRating: 4.8,
                    sessionsResolved: 18,
                    sessionsNeedsImprovement: 6
                )
            )
            self.isLoading = false
        }
    }
}

// MARK: - Profile Data Container
struct ProfileData {
    let userProfile: UserProfile
    let profileStats: ProfileStats
}
