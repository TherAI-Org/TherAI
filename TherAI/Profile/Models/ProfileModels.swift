import SwiftUI

// MARK: - User Profile Model
struct UserProfile {
    let firstName: String
    let lastName: String
    let partnerFirstName: String
    let partnerLastName: String
    let relationshipStartDate: Date
    let relationshipDuration: String
    let personalityType: String
    
    var relationshipStartMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: relationshipStartDate)
    }
}

// MARK: - Profile Stats Model
struct ProfileStats {
    let totalSessions: Int
    let newSessions: Int
    let averageRating: Double
    let sessionsResolved: Int
    let sessionsNeedsImprovement: Int
}

// MARK: - Session Item Model
struct SessionItem {
    let title: String
    let date: String
    let duration: String
    let status: String
}

// MARK: - Health Insight Data Model
struct HealthInsight {
    let title: String
    let value: String
    let description: String
    let color: Color
}
