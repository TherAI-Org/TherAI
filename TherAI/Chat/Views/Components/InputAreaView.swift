import SwiftUI
import UIKit

struct InputAreaView: View {

    @Binding var inputText: String
    @Binding var isLoading: Bool

    let isInputFocused: FocusState<Bool>.Binding
    let send: () -> Void
    let stop: () -> Void
    let onCreatedNewSession: (UUID) -> Void
    let onSendToPartner: () -> Void

    var body: some View {

        let isSendDisabled = !isLoading && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let cornerRadius: CGFloat = 24
        let sendSize: CGFloat = 28

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
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    // iOS 26+ Liquid Glass effect using .glassEffect()
                    Color.clear
                        .glassEffect()
                        .cornerRadius(cornerRadius)
                } else {
                    // Transparent fallback for older iOS versions
                    Color.clear
                }
            }
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.2), value: isInputFocused.wrappedValue)
    }
}

#Preview {
    @FocusState var isFocused: Bool
    return InputAreaView(
        inputText: .constant(""),
        isLoading: .constant(false),
        isInputFocused: $isFocused,
        send: {},
        stop: {},
        onCreatedNewSession: { _ in },
        onSendToPartner: {}
    )
}


