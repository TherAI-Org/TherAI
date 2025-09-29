import SwiftUI

struct ChatScreenView: View {

    @Binding var selectedMode: ChatMode
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
            Group {
                if selectedMode == .personal {
                    InputAreaView(
                        inputText: $chatViewModel.inputText,
                        isLoading: $chatViewModel.isLoading,
                        focusSnippet: $chatViewModel.focusSnippet,
                        isInputFocused: isInputFocused,
                        send: { chatViewModel.sendMessage() },
                        stop: { chatViewModel.stopGeneration() },
                        onCreatedNewSession: { _ in },
                        onSendToPartner: onSendToPartner
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.9), value: selectedMode)
                }
            }
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


