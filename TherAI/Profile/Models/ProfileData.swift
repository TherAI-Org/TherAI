import Foundation

struct ProfileData {
    let relationshipHeader: RelationshipHeader
    let profileStats: ProfileStats
}

extension ProfileData {
    static func load() -> ProfileData {
        ProfileData(
            relationshipHeader: RelationshipHeader(
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
    }
}



