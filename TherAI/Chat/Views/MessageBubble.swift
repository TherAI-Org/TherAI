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
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(message.isFromUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.isFromUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isFromUser ? .trailing : .leading)
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

