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
                Text(message.content)
                    .font(Typography.body)
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
                    )
                    .foregroundColor(.white)
                    .frame(maxWidth: 320, alignment: .trailing)
            } else {
                MarkdownRendererView(markdown: message.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
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


