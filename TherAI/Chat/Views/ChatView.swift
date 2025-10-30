import SwiftUI

struct ChatView: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    @EnvironmentObject private var sessionsViewModel: ChatSessionsViewModel

    @StateObject private var viewModel: ChatViewModel

    @FocusState private var isInputFocused: Bool
    @State private var showNotLinkedAlert: Bool = false
    // Partner accepted banner state (shows when app opened via partner link)
    @State private var showPartnerAddedBanner: Bool = false
    @State private var partnerAddedName: String = ""

    init(sessionId: UUID? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(sessionId: sessionId))
    }

    var body: some View {
        let handleSendToPartner: () -> Void = {
            guard sessionsViewModel.partnerInfo?.linked == true || UserDefaults.standard.bool(forKey: PreferenceKeys.partnerConnected) == true else {
                Haptics.notification(.error)
                showNotLinkedAlert = true
                return
            }
            let latestPartnerText = findLatestPartnerMessage()
            let inputTextTrimmed = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            let textToSend = latestPartnerText ?? (inputTextTrimmed.isEmpty ? nil : inputTextTrimmed)
            guard let text = textToSend, !text.isEmpty else { return }
            if latestPartnerText == nil { viewModel.inputText = "" }
            Task {
                await viewModel.sendToPartner(sessionsViewModel: sessionsViewModel, customMessage: text)
                // Only mark as sent after successful dispatch attempt (guarded inside sendToPartner)
                if sessionsViewModel.partnerInfo?.linked == true || UserDefaults.standard.bool(forKey: PreferenceKeys.partnerConnected) == true {
                    viewModel.partnerDrafts.markPartnerDraftAsSent(sessionId: viewModel.sessionId, messageContent: text)
                }
            }
        }

        return NavigationStack {
            ChatScreenView(
                chatViewModel: viewModel,
                onSendToPartner: handleSendToPartner,
                isInputFocused: $isInputFocused
            )
            .overlay(alignment: .top) { partnerAddedBannerOverlay }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        Haptics.impact(.medium)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        navigationViewModel.openSidebar()
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                .frame(width: 44, height: 44)

                            let unreadCount = sessionsViewModel.unreadPartnerSessionIds.count + sessionsViewModel.pendingRequests.count
                            if unreadCount > 0 {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    Text("\(min(unreadCount, 99))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .minimumScaleFactor(0.7)
                                        .lineLimit(1)
                                }
                                .frame(width: 16, height: 16)
                                .offset(x: -5, y: 5)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                if !viewModel.messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            Haptics.impact(.light)
                            sessionsViewModel.startNewChat()
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                .frame(width: 44, height: 44)
                                .offset(y: -1.5)
                        }
                        .transaction { txn in txn.animation = nil }
                        .animation(nil, value: viewModel.messages.isEmpty)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = false }
        .onAppear {
            // Do not focus input when sidebar is open
            if navigationViewModel.isOpen {
                isInputFocused = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if sessionsViewModel.activeSessionId == nil && !navigationViewModel.isOpen {
                        isInputFocused = true
                    }
                }
            }
        }
        .onChange(of: navigationViewModel.dragOffset, initial: false) { _, newValue in ChatSidebarViewModel.shared.handleSidebarDragChanged(newValue, setInputFocused: { isInputFocused = $0 }) }
        .onChange(of: navigationViewModel.isOpen, initial: false) { _, newValue in ChatSidebarViewModel.shared.handleSidebarIsOpenChanged(newValue, setInputFocused: { isInputFocused = $0 }) }
        .onAppear {
            Task { await sessionsViewModel.loadPendingRequests() }
            // Register this ChatViewModel with SessionsViewModel so it can preload cache
            sessionsViewModel.chatViewModel = viewModel
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("SendPartnerMessageFromBubble"))) { note in
            if let text = note.userInfo?["content"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if sessionsViewModel.partnerInfo?.linked == true || UserDefaults.standard.bool(forKey: PreferenceKeys.partnerConnected) == true {
                    Task {
                        await viewModel.sendToPartner(sessionsViewModel: sessionsViewModel, customMessage: text)
                        viewModel.partnerDrafts.markPartnerDraftAsSent(sessionId: viewModel.sessionId, messageContent: text)
                    }
                } else {
                    Haptics.notification(.error)
                    showNotLinkedAlert = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .partnerLinkOpened)) { note in
            // Use helper function that prioritizes user-entered partner_display_name
            partnerAddedName = PreferenceKeys.getPartnerDisplayName()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showPartnerAddedBanner = true
            }
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if showPartnerAddedBanner {
                    withAnimation(.easeInOut(duration: 0.35)) { showPartnerAddedBanner = false }
                }
            }
        }
        .onChange(of: sessionsViewModel.partnerInfo?.partner?.name ?? "", initial: false) { _, newName in
            // If banner is visible and we don't have a name yet, update once name arrives
            // Use helper function that prioritizes user-entered partner_display_name
            if showPartnerAddedBanner && partnerAddedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                partnerAddedName = PreferenceKeys.getPartnerDisplayName()
            }
        }
        // SkipPartnerDraftRequested no-op removed; feature not in use
        .onChange(of: sessionsViewModel.chatViewKey, initial: false) { _, _ in
            if sessionsViewModel.activeSessionId == nil {
                viewModel.sessionId = nil
                Task { await viewModel.loadHistory() }
            } else {
                ChatSidebarViewModel.shared.handleActiveSessionChanged(sessionsViewModel.activeSessionId, viewModel: viewModel)
            }
        }
        // Disable implicit animations related to this state change
        .animation(nil, value: viewModel.messages.isEmpty)
        .alert("Not connected", isPresented: $showNotLinkedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your account is not connected to a partner.")
        }
    }

    private func findLatestPartnerMessage() -> String? {
        for msg in viewModel.messages.reversed() {
            if let content = (msg as ChatMessage).partnerMessageContent,
               (msg as ChatMessage).isPartnerMessage,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return content
            }
        }
        return nil
    }

    @ViewBuilder
    private var partnerAddedBannerOverlay: some View {
        if showPartnerAddedBanner {
            VStack {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 34)
                        .background {
                            Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                        }
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You’ve been added as a partner to " + (partnerAddedName.isEmpty ? "your partner" : partnerAddedName))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    Spacer(minLength: 8)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.35)) { showPartnerAddedBanner = false }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                            .background {
                                Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer(minLength: 0)
            }
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)
                )
            )
            .animation(.easeInOut(duration: 0.35), value: showPartnerAddedBanner)
            .zIndex(20)
        } else {
            EmptyView()
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(SidebarNavigationViewModel())
        .environmentObject(ChatSessionsViewModel())
}

