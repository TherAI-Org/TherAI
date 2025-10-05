import SwiftUI
import UIKit

struct ChatScreenView: View {

    @Binding var selectedMode: ChatMode
    let isInputFocused: FocusState<Bool>.Binding

    @ObservedObject var chatViewModel: ChatViewModel

    let onDoubleTapPartnerMessage: (_: Any) -> Void
    let onSendToPartner: () -> Void

    @State private var inputBarHeight: CGFloat = 0
    @State private var bottomSafeInset: CGFloat = 0
    @State private var personalPreScrollToken: Int = 0
    @State private var keyboardScrollToken: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(
                selectedMode: $selectedMode,
                showDivider: !chatViewModel.messages.isEmpty
            )

            ChatContentView(
                selectedMode: selectedMode,
                personalMessages: chatViewModel.messages,
                emptyPrompt: chatViewModel.emptyPrompt,
                onDoubleTapPartnerMessage: { _ in },
                isInputFocused: isInputFocused.wrappedValue,
                onBackgroundTap: { isInputFocused.wrappedValue = false },
                personalPreScrollToken: personalPreScrollToken,
                keyboardScrollToken: keyboardScrollToken
            )
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: 50)
            }
            .padding(.bottom, inputBarHeight + bottomSafeInset)
        }
        .overlay(alignment: .bottom) {
            Group {
                if selectedMode == .personal {
                    VStack(spacing: 0) {
                        InputAreaView(
                            inputText: $chatViewModel.inputText,
                            isLoading: $chatViewModel.isLoading,
                            focusSnippet: $chatViewModel.focusSnippet,
                            isInputFocused: isInputFocused,
                            send: { chatViewModel.sendMessage() },
                            stop: { chatViewModel.stopGeneration() },
                            onSendToPartner: onSendToPartner
                        )
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: InputBarHeightPreferenceKey.self, value: proxy.size.height)
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.2, dampingFraction: 0.9), value: selectedMode)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
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
        .onAppear {
            bottomSafeInset = currentBottomSafeInset()
        }
        .onChange(of: chatViewModel.isLoadingHistory) { _, isLoading in
            if !isLoading && selectedMode == .personal && !chatViewModel.messages.isEmpty {
                personalPreScrollToken &+= 1
            }
        }
        .onChange(of: isInputFocused.wrappedValue) { _, isFocused in
            if isFocused && selectedMode == .personal && !chatViewModel.messages.isEmpty {
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


