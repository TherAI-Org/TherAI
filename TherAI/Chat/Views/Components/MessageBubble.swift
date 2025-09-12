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
                // User message: high contrast with bold purple background
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
                // AI message: subtle, elegant background
                Text(message.content)
                    .font(Typography.body)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.08), 
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: Color.black.opacity(0.03), 
                                radius: 4, 
                                x: 0, 
                                y: 2
                            )
                    )
                    .foregroundColor(.primary)
                    .frame(maxWidth: 320, alignment: .leading)
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

