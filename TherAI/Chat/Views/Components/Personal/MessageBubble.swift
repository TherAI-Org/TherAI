import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var onSendToPartner: ((String) -> Void)? = nil
    @State private var didSend: Bool = false

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
                VStack(alignment: .leading, spacing: 8) {
                    MarkdownRendererView(markdown: message.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    if message.isPartnerMessage, let text = message.partnerMessageContent, !text.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: {
                                guard !didSend else { return }
                                didSend = true
                                onSendToPartner?(text)
                            }) {
                                HStack(spacing: 10) {
                                    if didSend {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Sent")
                                            .font(.system(size: 16, weight: .semibold))
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Send to Partner")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            didSend
                                            ? LinearGradient(
                                                colors: [Color.green.opacity(0.85), Color.green.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                              )
                                            : LinearGradient(
                                                colors: [
                                                    Color(red: 0.4, green: 0.2, blue: 0.6),
                                                    Color(red: 0.35, green: 0.15, blue: 0.55)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                              )
                                        )
                                )
                            }
                            .disabled(didSend)
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }
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


