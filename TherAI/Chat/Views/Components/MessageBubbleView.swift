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
                    let body = assistantBodyExcludingDraft(message)
                    if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        MarkdownRendererView(markdown: body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                    }
                    if message.isPartnerMessage, let text = message.partnerMessageContent, !text.isEmpty {
                        PartnerDraftBlockView(initialText: text) { action in
                            switch action {
                            case .send(let edited):
                                onSendToPartner?(edited)
                            case .skip:
                                NotificationCenter.default.post(name: .init("SkipPartnerDraftRequested"), object: nil, userInfo: ["messageId": message.id.uuidString])
                            }
                        }
                        .id(text)
                        .padding(.top, 6)
                    }
                }
            }
        }
    }

    private func assistantBodyExcludingDraft(_ message: ChatMessage) -> String {
        // If content is a structured partner draft annotation, don't render it as markdown
        if isPartnerDraftAnnotation(message.content) { return "" }

        guard let draft = message.partnerMessageContent, !draft.isEmpty else {
            return message.content
        }

        let content = message.content
        if let range = content.range(of: draft) {
            var result = content
            result.removeSubrange(range)
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Try with surrounding quotes removed
        let quotedVariants = ["\"" + draft + "\"", "“" + draft + "”", "'" + draft + "'"]
        for variant in quotedVariants {
            if let r = content.range(of: variant) {
                var result = content
                result.removeSubrange(r)
                return result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // If content equals the draft, nothing to render as body
        if content.trimmingCharacters(in: .whitespacesAndNewlines) == draft.trimmingCharacters(in: .whitespacesAndNewlines) {
            return ""
        }
        return content
    }

    private func isPartnerDraftAnnotation(_ content: String) -> Bool {
        guard let data = content.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let therai = obj["_therai"] as? [String: Any],
              let type = therai["type"] as? String else { return false }
        return type == "partner_draft"
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


