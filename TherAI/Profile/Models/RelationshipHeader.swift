import Foundation

struct RelationshipHeader {
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



