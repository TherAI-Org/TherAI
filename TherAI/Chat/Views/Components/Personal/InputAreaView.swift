import SwiftUI
import UIKit

struct InputAreaView: View {

    @Binding var inputText: String
    @Binding var isLoading: Bool
    @Binding var focusSnippet: String?

    let isInputFocused: FocusState<Bool>.Binding
    let send: () -> Void
    let stop: () -> Void
    let onCreatedNewSession: (UUID) -> Void
    let onSendToPartner: () -> Void

    var body: some View {

        let isSendDisabled = !isLoading && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let sendSize: CGFloat = 28

        VStack(alignment: .leading, spacing: 8) {
            if let snippet = focusSnippet, !snippet.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .foregroundColor(.secondary)
                    Text(snippet)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Button(action: { withAnimation { focusSnippet = nil } }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 12) {
                TextField("Share what's on your mind", text: $inputText)
                    .font(Typography.body)
                    .foregroundColor(.primary)
                    .onSubmit {
                        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        Haptics.impact(.light)
                        send()
                    }
                    .focused(isInputFocused)

                Button(action: {
                    Haptics.impact(.light)

                    if isLoading {
                        stop()
                    } else {
                        send()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isSendDisabled ?
                                  Color(uiColor: .systemGray5) :
                                  Color(red: 0.4, green: 0.2, blue: 0.6))
                            .frame(width: sendSize, height: sendSize)

                        Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isSendDisabled ? .secondary : .white)
                    }
                }
                .disabled(isSendDisabled)
                .scaleEffect(isSendDisabled ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSendDisabled)
                .contextMenu {
                    Button(action: {
                        send()
                    }) {
                        Label("Send to Personal", systemImage: "person.circle")
                    }

                    Button(action: {
                        onSendToPartner()
                    }) {
                        Label("Send to Partner", systemImage: "heart.circle")
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: isInputFocused.wrappedValue)
    }
}

#Preview {
    @FocusState var isFocused: Bool
    InputAreaView(
        inputText: .constant(""),
        isLoading: .constant(false),
        focusSnippet: .constant(nil),
        isInputFocused: $isFocused,
        send: {},
        stop: {},
        onCreatedNewSession: { _ in },
        onSendToPartner: {}
    )
}



