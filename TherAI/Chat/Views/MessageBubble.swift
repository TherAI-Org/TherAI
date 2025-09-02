import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                messageContent
            } else {
                messageContent
                Spacer()
            }
        }
    }

    private var messageContent: some View {
        VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
            if message.isFromUser {
                // User message: gray bubble with black-ish outline
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.black.opacity(0.9), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.primary)
                    .frame(maxWidth: 500, alignment: .trailing)
            } else {
                // Assistant message: plain text only
                Text(message.content)
                    .foregroundColor(.primary)
                    .padding(.top, 4)
                    .frame(maxWidth: 500, alignment: .leading)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MessageBubble(message: ChatMessage(content: "Hello! How are you?", isFromUser: true))
        MessageBubble(message: ChatMessage(content: "I'm doing great, thanks for asking!", isFromUser: false))
    }
    .padding()
}

