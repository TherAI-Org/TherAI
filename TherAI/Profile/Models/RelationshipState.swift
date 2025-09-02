import SwiftUI

struct RelationshipState {
    let title: String
    let value: String
    let description: String
    let color: Color
}

// Mock data as a separate extension
extension RelationshipState {
    static let mocks: [RelationshipState] = [
        RelationshipState(title: "Communication Score", value: "9.2/10", description: "Excellent verbal and non-verbal communication patterns", color: .blue),
        RelationshipState(title: "Trust Level", value: "Strong", description: "Both partners demonstrate high trust and reliability", color: .green),
        RelationshipState(title: "Emotional Connection", value: "Strong", description: "Strong emotional bonding and empathy shown", color: .pink),
        RelationshipState(title: "Conflict Resolution", value: "Effective", description: "Healthy conflict resolution strategies in place", color: .purple)
    ]
}
