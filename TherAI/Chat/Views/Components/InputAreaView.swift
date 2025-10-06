import SwiftUI
import UIKit

struct InputAreaView: View {

    @Binding var inputText: String
    @Binding var isLoading: Bool
    @Binding var focusSnippet: String?

    let isInputFocused: FocusState<Bool>.Binding
    let send: () -> Void
    let stop: () -> Void
    let onSendToPartner: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {

        let isSendDisabled = !isLoading && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let sendSize: CGFloat = 34

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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark ?
                                Color.white.opacity(0.12) :
                                Color.black.opacity(0.06),
                            lineWidth: 1
                        )
                )
            }

            HStack(alignment: .bottom, spacing: 4) {
                VStack {
                    TextField("Share what's on your mind", text: $inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .lineSpacing(2)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.primary)
                        .textFieldStyle(.plain)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .focused(isInputFocused)
                }
                .frame(minHeight: 36)

                Button(action: {
                    Haptics.impact(.light)

                    if isLoading {
                        stop()
                    } else {
                        isInputFocused.wrappedValue = false
                        send()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                isSendDisabled ?
                                    LinearGradient(
                                        colors: [Color(white: colorScheme == .dark ? 0.25 : 0.90)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.5, green: 0.3, blue: 0.7),
                                            Color(red: 0.4, green: 0.2, blue: 0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: sendSize, height: sendSize)
                            .shadow(color: isSendDisabled ? .clear : Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), radius: 4, x: 0, y: 2)

                        Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isSendDisabled ? Color(.systemGray2) : .white)
                    }
                }
                .disabled(isSendDisabled)
                .scaleEffect(isSendDisabled ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSendDisabled)
                .contextMenu {
                    Button(action: {
                        send()
                    }) {
                        Label("Send to Personal", systemImage: "person.circle")
                    }
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark ?
                        Color.white.opacity(0.15) :
                        Color.black.opacity(0.08),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        onSendToPartner: {}
    )
}



