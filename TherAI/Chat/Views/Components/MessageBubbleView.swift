import SwiftUI

struct MessageBubbleView: View {
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
                    .font(.system(size: 17, weight: .regular))
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
                        PartnerDraftBlockView(initialText: text) { action in
                            switch action {
                            case .send(let edited):
                                onSendToPartner?(edited)
                            case .skip:
                                NotificationCenter.default.post(name: .init("SkipPartnerDraftRequested"), object: nil, userInfo: ["messageId": message.id.uuidString])
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MessageBubbleView(message: ChatMessage(content: "Hello! How are you?", isFromUser: true))
        MessageBubbleView(message: ChatMessage(content: "I’m doing great, thanks for asking!", isFromUser: false))
        MessageBubbleView(
            message: ChatMessage(
                content: "Sure—here’s a message you could send:",
                isFromUser: false,
                isPartnerMessage: true,
                partnerMessageContent: "Hey love — I’ve been feeling a bit overwhelmed lately and could use a little extra help this week. Could we sit down tonight and figure out a plan that feels fair for both of us?"
            ),
            onSendToPartner: { _ in }
        )
    }
    .padding()
}


