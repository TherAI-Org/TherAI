import SwiftUI
import UIKit

struct ChatScreenView: View {

    let isInputFocused: FocusState<Bool>.Binding

    @ObservedObject var chatViewModel: ChatViewModel

    let onDoubleTapPartnerMessage: (_: Any) -> Void
    let onSendToPartner: () -> Void

    @State private var inputBarHeight: CGFloat = 0
    @State private var suggestionsHeight: CGFloat = 0
    @State private var bottomSafeInset: CGFloat = 0
    @State private var keyboardScrollToken: Int = 0
    @State private var showSuggestionsDelayed: Bool = false
    @State private var suggestionsDelayWorkItem: DispatchWorkItem?

    private var quickSuggestions: [QuickSuggestion] {
        return [
            QuickSuggestion(title: "Talk about", subtitle: "a recent argument that's still on my mind"),
            QuickSuggestion(title: "How can I", subtitle: "set healthier boundaries without hurting them?"),
            QuickSuggestion(title: "We keep", subtitle: "misunderstanding each other—how do we reset?"),
            QuickSuggestion(title: "I'm worried", subtitle: "we're growing apart—what signs should I look for?"),
            QuickSuggestion(title: "What are", subtitle: "ways to rebuild trust after it's been broken?"),
            QuickSuggestion(title: "Help me", subtitle: "prepare for a hard conversation tonight")
        ]
    }

    private var isNewChatReadyForSuggestions: Bool {
        chatViewModel.messages.isEmpty && !chatViewModel.isLoadingHistory && !chatViewModel.isLoading
    }

    var body: some View {
        let canShowSuggestions = isNewChatReadyForSuggestions && showSuggestionsDelayed

        VStack(spacing: 0) {
            ChatHeaderView(
                showDivider: !chatViewModel.messages.isEmpty
            )

            // Inlined ChatContentView
            MessagesListView(
                messages: chatViewModel.messages,
                chatViewModel: chatViewModel,
                isInputFocused: isInputFocused.wrappedValue,
                onBackgroundTap: { isInputFocused.wrappedValue = false },
                preScrollTrigger: 0,
                keyboardScrollTrigger: keyboardScrollToken,
                onPreScrollComplete: nil,
                isAssistantTyping: chatViewModel.isAssistantTyping,
                focusTopId: chatViewModel.focusTopMessageId,
                streamingScrollToken: chatViewModel.streamingScrollToken,
                streamingTargetId: chatViewModel.assistantScrollTargetId,
                initialJumpToken: chatViewModel.initialJumpToken
            )
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 50)
            }
            .padding(
                .bottom,
                inputBarHeight + (canShowSuggestions ? suggestionsHeight : 0) + bottomSafeInset
            )
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                if canShowSuggestions {
                    QuickSuggestionsView(
                        suggestions: quickSuggestions,
                        onTap: { text in
                            Haptics.impact(.light)
                            chatViewModel.inputText = text
                            chatViewModel.sendMessage()
                        }
                    )
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: SuggestionsHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity), // flow up on appear
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
                } else {
                    Color.clear.frame(height: 0).onAppear { suggestionsHeight = 0 }
                }

                InputAreaView(
                    inputText: $chatViewModel.inputText,
                    isLoading: $chatViewModel.isLoading,
                    focusSnippet: $chatViewModel.focusSnippet,
                    isInputFocused: isInputFocused,
                    send: { chatViewModel.sendMessage() },
                    stop: { chatViewModel.stopGeneration() },
                    onSendToPartner: onSendToPartner,
                    onVoiceRecordingStart: { chatViewModel.startVoiceRecording() },
                    onVoiceRecordingStop: { _ in }
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: InputBarHeightPreferenceKey.self, value: proxy.size.height)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .ignoresSafeArea(edges: .bottom)
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
        .onPreferenceChange(InputBarHeightPreferenceKey.self) { newHeight in
            inputBarHeight = newHeight
        }
        .onPreferenceChange(SuggestionsHeightPreferenceKey.self) { newHeight in
            suggestionsHeight = newHeight
        }
        .onAppear {
            bottomSafeInset = currentBottomSafeInset()
            // Schedule delayed appearance if entering a new chat
            if isNewChatReadyForSuggestions {
                suggestionsDelayWorkItem?.cancel()
                let work = DispatchWorkItem {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                        showSuggestionsDelayed = true
                    }
                }
                suggestionsDelayWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
            } else {
                showSuggestionsDelayed = false
            }
        }
        // Removed pre-scroll behavior to avoid visible scrolling on load
        .onChange(of: isNewChatReadyForSuggestions) { _, ready in
            if ready {
                suggestionsDelayWorkItem?.cancel()
                let work = DispatchWorkItem {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                        showSuggestionsDelayed = true
                    }
                }
                suggestionsDelayWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
            } else {
                suggestionsDelayWorkItem?.cancel()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.95)) {
                    showSuggestionsDelayed = false
                }
            }
        }
        .onChange(of: isInputFocused.wrappedValue) { _, isFocused in
            if isFocused && !chatViewModel.messages.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    keyboardScrollToken &+= 1
                }
            }
        }
    }
}

private func currentBottomSafeInset() -> CGFloat {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return 0 }
    return window.safeAreaInsets.bottom
}

private struct InputBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SuggestionsHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}