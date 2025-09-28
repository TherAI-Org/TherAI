import SwiftUI

struct SessionsExpandedListView: View {
    let title: String
    let sessions: [CommunicationSession]
    let gradient: [Color]
    var expansionProgress: CGFloat = 1.0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        let sessionCount = CGFloat(sessions.count)
                        let step = 1.0 / max(sessionCount, 1)
                        let startThreshold = CGFloat(index) * step
                        let sessionProgress = max(0, min(1, (expansionProgress - startThreshold) / step))

                        ExpandedSessionRowView(session: session)
                            .opacity(sessionProgress)
                            .offset(x: 0, y: (1 - sessionProgress) * 16)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1), value: sessionProgress)
                            .allowsHitTesting(expansionProgress > 0.1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .frame(height: 320)
            .clipped()
        }
        .background(
            Group {
                if colorScheme == .light {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white)
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(.systemGray6),
                                    Color(.systemGray6).opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}


#Preview {
    SessionsExpandedListView(
        title: "Sessions Resolved",
        sessions: [
            CommunicationSession(title: "Communication Breakthrough", date: "2 days ago", duration: "45 min", status: "Resolved"),
            CommunicationSession(title: "Trust Building Exercise", date: "1 week ago", duration: "30 min", status: "Resolved"),
            CommunicationSession(title: "Feedback Loop", date: "3 days ago", duration: "25 min", status: "Needs Attention")
        ],
        gradient: [.green, .green.opacity(0.7)],
        expansionProgress: 1
    )
    .padding(20)
}


