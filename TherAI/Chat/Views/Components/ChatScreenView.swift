import SwiftUI

struct ChatScreenView: View {

    @Binding var selectedMode: PickerView.ChatMode
    let isInputFocused: FocusState<Bool>.Binding

    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var dialogueViewModel: DialogueViewModel

    let onDoubleTapPartnerMessage: (DialogueViewModel.DialogueMessage) -> Void
    let onSendToPartner: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(selectedMode: $selectedMode)

            ChatContentView(
                selectedMode: selectedMode,
                personalMessages: chatViewModel.messages,
                dialogueMessages: dialogueViewModel.messages,
                emptyPrompt: chatViewModel.emptyPrompt,
                onDoubleTapPartnerMessage: onDoubleTapPartnerMessage,
                isInputFocused: isInputFocused.wrappedValue,
                onBackgroundTap: { isInputFocused.wrappedValue = false }
            )
        }
        .safeAreaInset(edge: .bottom) {
            ChatInputContainerView(
                selectedMode: selectedMode,
                inputText: $chatViewModel.inputText,
                isLoading: $chatViewModel.isLoading,
                focusSnippet: $chatViewModel.focusSnippet,
                isInputFocused: isInputFocused,
                send: { chatViewModel.sendMessage() },
                stop: { chatViewModel.stopGeneration() },
                onSendToPartner: onSendToPartner
            )
            .background(Color(.systemBackground))
        }
        .overlay {
            if chatViewModel.isLoadingHistory && chatViewModel.messages.isEmpty {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    ProgressView().progressViewStyle(.circular)
                }
                .transition(.opacity)
            }
        }
        .background(Color(.systemBackground))
    }
}


