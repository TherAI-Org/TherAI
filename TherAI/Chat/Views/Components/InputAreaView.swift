import SwiftUI
import UIKit

struct InputAreaView: View {

    @Binding var inputText: String

    let isInputFocused: FocusState<Bool>.Binding
    let send: () -> Void
    let onCreatedNewSession: (UUID) -> Void

    var body: some View {

        let isSendDisabled = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let borderWidth: CGFloat = 1.5
        let cornerRadius: CGFloat = 18
        let sendSize: CGFloat = 40

        HStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Ask anything", text: $inputText)
                    .onSubmit { send() }
                    .focused(isInputFocused)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(uiColor: .systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.black, lineWidth: borderWidth)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
            )

            Button(action: { send() }) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .systemBackground))
                        .frame(width: sendSize, height: sendSize)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: borderWidth)
                        )

                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSendDisabled ? .secondary : .primary)
                }
            }
            .disabled(isSendDisabled)
            .opacity(isSendDisabled ? 0.6 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }
}

#Preview {
    @FocusState var isFocused: Bool
    return InputAreaView(
        inputText: .constant(""),
        isInputFocused: $isFocused,
        send: {},
        onCreatedNewSession: { _ in }
    )
}


