import Foundation

struct ProfileData {
    let profileStats: ProfileStats
}

extension ProfileData {
    static func load() -> ProfileData {
        ProfileData(
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



