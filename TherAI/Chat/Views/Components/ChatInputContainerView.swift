import SwiftUI

struct ChatInputContainerView: View {

    let selectedMode: PickerView.ChatMode
    @Binding var inputText: String
    @Binding var isLoading: Bool
    @Binding var focusSnippet: String?
    let isInputFocused: FocusState<Bool>.Binding
    let send: () -> Void
    let stop: () -> Void
    let onSendToPartner: () -> Void

    var body: some View {
        Group {
            if selectedMode == .personal {
                InputAreaView(
                    inputText: $inputText,
                    isLoading: $isLoading,
                    focusSnippet: $focusSnippet,
                    isInputFocused: isInputFocused,
                    send: send,
                    stop: stop,
                    onCreatedNewSession: { _ in },
                    onSendToPartner: onSendToPartner
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: selectedMode)
            }
        }
    }
}


