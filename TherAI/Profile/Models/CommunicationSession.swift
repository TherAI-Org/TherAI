import Foundation
import SwiftUI

struct CommunicationSession {
    let title: String
    let date: String
    let duration: String
    let status: String
}

extension CommunicationSession {
    var statusColor: Color {
        switch status {
        case "Resolved":
            return .green
        case "In Progress":
            return .blue
        case "Needs Work":
            return .orange
        case "Review Required":
            return .red
        default:
            return .gray
        }
    }
}

// Mock data as a separate extension
extension CommunicationSession {
    static let mocksResolved: [CommunicationSession] = [
        CommunicationSession(title: "Communication Breakthrough", date: "2 days ago", duration: "45 min", status: "Resolved"),
        CommunicationSession(title: "Trust Building Exercise", date: "1 week ago", duration: "30 min", status: "Resolved"),
        CommunicationSession(title: "Future Planning Discussion", date: "2 weeks ago", duration: "60 min", status: "Resolved"),
        CommunicationSession(title: "Emotional Intelligence Workshop", date: "3 weeks ago", duration: "55 min", status: "Resolved"),
        CommunicationSession(title: "Relationship Goals Setting", date: "1 month ago", duration: "40 min", status: "Resolved"),
        CommunicationSession(title: "Conflict Resolution Practice", date: "1 month ago", duration: "50 min", status: "Resolved"),
        CommunicationSession(title: "Communication Skills Review", date: "2 months ago", duration: "35 min", status: "Resolved"),
        CommunicationSession(title: "Trust Building Activities", date: "2 months ago", duration: "45 min", status: "Resolved")
    ]

    static let mocksImprovement: [CommunicationSession] = [
        CommunicationSession(title: "Conflict Resolution", date: "3 days ago", duration: "40 min", status: "In Progress"),
        CommunicationSession(title: "Emotional Expression", date: "1 week ago", duration: "35 min", status: "Needs Work"),
        CommunicationSession(title: "Active Listening Practice", date: "2 weeks ago", duration: "50 min", status: "Review Required"),
        CommunicationSession(title: "Anger Management Skills", date: "3 weeks ago", duration: "45 min", status: "Needs Work"),
        CommunicationSession(title: "Stress Communication", date: "1 month ago", duration: "40 min", status: "In Progress")
    ]
}



