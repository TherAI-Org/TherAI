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
                    if isFromCurrentUser {
                        Text(message.content)
                            .font(Typography.body)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.2, blue: 0.6),
                                                Color(red: 0.35, green: 0.15, blue: 0.55)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(
                                        color: Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.25),
                                        radius: 8,
                                        x: 0,
                                        y: 3
                                    )
                            )
                            .foregroundColor(.white)
                            .frame(maxWidth: 320, alignment: .trailing)
                    } else {
                        Text(message.content)
                            .font(Typography.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
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



