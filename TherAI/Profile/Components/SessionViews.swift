import SwiftUI

// MARK: - Expanded Sessions View (Full Width)
struct ExpandedSessionsView: View {
    let title: String
    let sessions: [SessionItem]
    let gradient: [Color]
    var expansionProgress: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with title and icon
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: gradient == [.green, .green.opacity(0.7)] ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Scrollable session rows with fixed height to show only 4 at once
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        // Compute per-row reveal progress based on overall expansion progress
                        // For closing animation, reverse the order so last items disappear first
                        let sessionCount = CGFloat(sessions.count)
                        let step = 1.0 / max(sessionCount, 1)
                        let startThreshold = CGFloat(index) * step
                        let sessionProgress = max(0, min(1, (expansionProgress - startThreshold) / step))

                        ExpandedSessionRow(session: session)
                            .opacity(sessionProgress)
                            .offset(x: 0, y: (1 - sessionProgress) * 16)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1), value: sessionProgress)
                            .allowsHitTesting(expansionProgress > 0.1) // Disable interaction during closing
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(height: 320) // Fixed height to show exactly 4 sessions
            .clipped()
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemBackground).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Expanded Session Row
struct ExpandedSessionRow: View {
    let session: SessionItem
    
    var body: some View {
        // Main session row - ready for future navigation to chat
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(session.duration)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(session.date)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Status badge
            Text(session.status)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(statusColor)
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    private var statusColor: Color {
        switch session.status {
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

#Preview {
    ExpandedSessionsView(
        title: "Sessions Resolved",
        sessions: [
            SessionItem(title: "Communication Breakthrough", date: "2 days ago", duration: "45 min", status: "Resolved"),
            SessionItem(title: "Trust Building Exercise", date: "1 week ago", duration: "30 min", status: "Resolved")
        ],
        gradient: [.green, .green.opacity(0.7)]
    )
    .padding(20)
}
