import SwiftUI

struct ExpandedSessionRowView: View {
    let session: CommunicationSession

    var body: some View {
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

    private var statusColor: Color { session.statusColor }
}


#Preview {
    VStack(spacing: 12) {
        ExpandedSessionRowView(
            session: CommunicationSession(
                title: "Communication Breakthrough",
                date: "2 days ago",
                duration: "45 min",
                status: "Resolved"
            )
        )

        ExpandedSessionRowView(
            session: CommunicationSession(
                title: "Boundary Setting",
                date: "Yesterday",
                duration: "30 min",
                status: "Needs Attention"
            )
        )
    }
    .padding(20)
}


