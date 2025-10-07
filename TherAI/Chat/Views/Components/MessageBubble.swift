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
                        PartnerDraftBlock(initialText: text) { action in
                            switch action {
                            case .send(let edited):
                                onSendToPartner?(edited)
                            case .skip:
                                NotificationCenter.default.post(name: .init("SkipPartnerDraftRequested"), object: nil, userInfo: ["messageId": message.id.uuidString])
                            case .reject:
                                NotificationCenter.default.post(name: .init("RejectPartnerDraftRequested"), object: nil, userInfo: ["messageId": message.id.uuidString])
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
    }
}

private struct PartnerDraftBlock: View {
    enum Action { case send(String), skip, reject }
    @State var text: String
    let onAction: (Action) -> Void

    init(initialText: String, onAction: @escaping (Action) -> Void) {
        self._text = State(initialValue: initialText)
        self.onAction = onAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Draft to your partner")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.secondary)
            TextEditor(text: $text)
                .font(.system(size: 16))
                .frame(minHeight: 80)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))
                )
            HStack(spacing: 10) {
                Button(action: { onAction(.send(text.trimmingCharacters(in: .whitespacesAndNewlines))) }) {
                    Label("Send", systemImage: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)

                Button(action: { onAction(.skip) }) {
                    Label("Skip", systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .regular))
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: { onAction(.reject) }) {
                    Label("Reject", systemImage: "xmark.circle")
                        .font(.system(size: 15, weight: .regular))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground))
                )
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        MessageBubble(message: ChatMessage(content: "Hello! How are you?", isFromUser: true))
        MessageBubble(message: ChatMessage(content: "I’m doing great, thanks for asking!", isFromUser: false))
        MessageBubble(
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


