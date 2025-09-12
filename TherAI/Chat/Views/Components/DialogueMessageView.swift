import SwiftUI

struct DialogueMessageView: View {
    let message: DialogueViewModel.DialogueMessage
    let currentUserId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Message content
            HStack {
                if isFromCurrentUser {
                    Spacer()
                }

                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    // AI/partner message: plain text for non-user, bubble only for current user to keep affordance
                    if isFromCurrentUser {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue)
                            )
                    } else {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }

                    Text(formatTimestamp(message.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !isFromCurrentUser {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var isFromCurrentUser: Bool {
        guard let currentUserId = currentUserId else { return false }
        return message.senderUserId == currentUserId
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"

        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .none
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return timestamp
    }
}

#Preview {
    DialogueMessageView(
        message: DialogueViewModel.DialogueMessage(
            id: UUID(),
            dialogueSessionId: UUID(),
            requestId: UUID(),
            content: "Hey Mike, Sarah has been feeling a bit lonely lately. She fears losing you due to your rigorous work schedule.",
            messageType: "request",
            senderUserId: UUID(),
            createdAt: "2024-01-15T14:30:00.000000Z"
        ),
        currentUserId: UUID()
    )
}



