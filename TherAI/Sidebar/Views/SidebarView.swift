import SwiftUI

struct SlideOutSidebarView: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    @EnvironmentObject private var sessionsViewModel: ChatSessionsViewModel
    @EnvironmentObject private var linkVM: LinkViewModel

    @Environment(\.colorScheme) private var colorScheme

    @Binding var isOpen: Bool

    @State private var isSearching: Bool = false
    @State private var searchText: String = ""

    @FocusState private var isSearchFocused: Bool

    let profileNamespace: Namespace.ID

    private func shouldShowLastMessage(_ content: String?) -> Bool {
        guard let content = content else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.uppercased() != "NULL"
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    let searchTint = colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.7)
                    if !isSearching {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(searchTint)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    ZStack(alignment: .leading) {
                        if searchText.isEmpty {
                            Text("Search")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(searchTint)
                        }
                        TextField("", text: $searchText)
                            .font(.system(size: 17, weight: .regular))
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .focused($isSearchFocused)
                            .onTapGesture { isSearching = true }
                    }
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; isSearchFocused = true }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.95), value: isSearching)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if #available(iOS 26.0, *) {
                            // iOS 26+ Liquid Glass effect using .glassEffect()
                            Color.clear
                                .glassEffect()
                                .clipShape(Capsule())
                        } else {
                            // Fallback for older iOS versions
                            LinearGradient(
                                colors: [
                                    Color(white: colorScheme == .dark ? 0.14 : 0.945),
                                    Color(white: colorScheme == .dark ? 0.17 : 0.965)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )

                .clipShape(Capsule())
                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    isSearching = true
                    isSearchFocused = true
                }
                Spacer().frame(width: 18)

                if isSearching {
                    Button("Cancel") {
                        Haptics.impact(.medium)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            isSearching = false
                            isSearchFocused = false
                        }
                        searchText = ""
                    }
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button(action: {
                        Haptics.impact(.medium)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0)) {
                            if sessionsViewModel.activeSessionId != nil {
                                // User has an active session, return to it
                                navigationViewModel.selectedTab = .chat
                                isOpen = false
                            } else {
                                // No active session, start a new one
                                sessionsViewModel.startNewChat()
                                navigationViewModel.selectedTab = .chat
                                isOpen = false
                            }
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
            .padding(.vertical, 8)
            .padding(.top, 8)
            .onChange(of: isSearchFocused) { old, newVal in
                isSearching = newVal
            }

            ScrollView {
                VStack(spacing: 10) {

                    // Only show pending requests, new conversation button, divider, and conversations header when not searching
                    if !isSearching {
                        let hasPending = !sessionsViewModel.pendingRequests.isEmpty

                        if hasPending {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(sessionsViewModel.pendingRequests) { request in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                            sessionsViewModel.openPendingRequest(request)
                                            isOpen = false
                                        }
                                    }) {
                                        HStack(alignment: .top, spacing: 12) {
                                            Image(systemName: "person.crop.circle.badge.plus")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Partner Request")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.primary)
                                                Text(request.requestContent)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(2)
                                            }
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemGray6))
                            )
                            .padding(.horizontal, 16)
                        }

                        VStack(spacing: 0) {
                            Button(action: {
                                Haptics.impact(.medium)
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0)) {
                                    sessionsViewModel.startNewChat()
                                    navigationViewModel.selectedTab = .chat
                                    isOpen = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    Text("New Conversation")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                        .offset(y: 2)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                            }

                            Divider()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                                .padding(.bottom, 4)

                            // Conversations header
                            HStack(spacing: 12) {
                                Text("Conversations")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        }
                        .offset(y: isSearching ? -120 : 0)
                        .opacity(isSearching ? 0 : 1)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearching)
                    }

                    let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let lower = term.lowercased()
                    let filteredSessions = sessionsViewModel.sessions.filter { session in
                        if lower.isEmpty { return true }
                        return session.displayTitle.lowercased().contains(lower)
                    }

                    // Search feedback - only show when searching and has search term
                    if isSearching && !lower.isEmpty {
                        HStack(spacing: 12) {
                            if !filteredSessions.isEmpty {
                                Text("\(filteredSessions.count) results for \"\(term)\"")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("No results for \"\(term)\"")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    LazyVStack(spacing: 6) {
                            if sessionsViewModel.isLoadingSessions {
                                VStack(spacing: 16) {
                                    ProgressView()
                                    Text("Loading sessions…")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            } else if !filteredSessions.isEmpty {
                                ForEach(filteredSessions, id: \.id) { session in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                            sessionsViewModel.openSession(session.id)
                                            navigationViewModel.selectedTab = .chat
                                            isOpen = false
                                            if isSearching {
                                                isSearching = false
                                                isSearchFocused = false
                                            }
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Text(session.displayTitle)
                                                    .font(.system(size: 18, weight: .regular))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Text(sessionsViewModel.formatLastUsed(session.lastUsedISO8601))
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                            }
                                            Text(shouldShowLastMessage(session.lastMessageContent) ? session.lastMessageContent! : "No messages yet")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .offset(y: isSearching ? -8 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearching)
                }
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .refreshable {
                await sessionsViewModel.refreshSessions()
            }
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSearching {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        isSearching = false
                        isSearchFocused = false
                    }
                    searchText = ""
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                // Extended gradient area that starts much higher
                Spacer()
                    .frame(height: 100) // This creates space for the gradient to start earlier

                HStack {
                    if case .linked = linkVM.state {
                        Button(action: {
                            Haptics.impact(.medium)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0)) {
                                navigationViewModel.showProfileOverlay = true
                            }
                        }) {
                            // Disable matched geometry for profile to avoid fly-up; open like settings
                            ProfileButtonView(profileNamespace: profileNamespace, compact: true, useMatchedGeometry: false)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    // Settings on lower right
                    Button(action: {
                        Haptics.impact(.medium)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0)) {
                            navigationViewModel.showSettingsOverlay = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.26, green: 0.58, blue: 1.00),
                                            Color(red: 0.63, green: 0.32, blue: 0.98)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.8), lineWidth: 1)
                                )

                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .offset(y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 34) // More bottom padding to bring icons further up
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground).opacity(0.3),
                        Color(.systemBackground).opacity(0.98),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)    // Opt out of keyboard avoidance
            .ignoresSafeArea(.container, edges: .bottom)   // Ignore container safe area
            .padding(.bottom, -geometry.safeAreaInsets.bottom)      // Cancel the keyboard's bottom inset so it won't rise
            .zIndex(10)  // Higher z-index to ensure it stays on top
            .allowsHitTesting(true)  // Ensure buttons remain interactive
            .offset(y: isSearching ? 100 : 0)  // Smoothly hide when searching
            .opacity(isSearching ? 0 : 1)      // Fade out when searching
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSearching)
        }
        }
    }
}

#Preview("Pending Requests") {
    struct PreviewWithPending: View {
        @Namespace var ns
        let navigationViewModel: SidebarNavigationViewModel
        let sessionsViewModel: ChatSessionsViewModel
        init() {
            let navVM = SidebarNavigationViewModel()
            let sessionsVM = ChatSessionsViewModel()
            sessionsVM.sessions = [
                ChatSession(id: UUID(), title: "Chat with Good Rudi", lastUsedISO8601: "2025-08-29T10:12:00Z", lastMessageContent: "Thanks for the help with the project! This was really useful and I learned a lot from our conversation."),
                ChatSession(id: UUID(), title: "Conversation name", lastUsedISO8601: "2025-09-01T08:00:00Z", lastMessageContent: "Can you explain how this works?"),
                ChatSession(id: UUID(), title: "Weekend plans", lastUsedISO8601: "2025-07-15T18:30:00Z", lastMessageContent: "Let's meet at the coffee shop at 2pm on Saturday")
            ]
            sessionsVM.isLoadingSessions = false
            // Seed example pending requests
            sessionsVM.pendingRequests = [
                DialogueViewModel.DialogueRequest(
                    id: UUID(),
                    senderUserId: UUID(),
                    senderSessionId: UUID(),
                    requestContent: "Partner request: Share chat access?",
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    status: "pending"
                ),
                DialogueViewModel.DialogueRequest(
                    id: UUID(),
                    senderUserId: UUID(),
                    senderSessionId: UUID(),
                    requestContent: "Invite from S: Connect for dialogue session",
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    status: "pending"
                )
            ]
            self.navigationViewModel = navVM
            self.sessionsViewModel = sessionsVM
        }
        var body: some View {
            SlideOutSidebarView(isOpen: .constant(true), profileNamespace: ns)
                .environmentObject(navigationViewModel)
                .environmentObject(sessionsViewModel)
                .environmentObject(LinkViewModel(accessTokenProvider: { "" }))
        }
    }
    return PreviewWithPending()
}

#Preview("Default") {
    struct PreviewNoPending: View {
        @Namespace var ns
        let navigationViewModel: SidebarNavigationViewModel
        let sessionsViewModel: ChatSessionsViewModel
        init() {
            let navVM = SidebarNavigationViewModel()
            let sessionsVM = ChatSessionsViewModel()
            sessionsVM.sessions = [
                ChatSession(id: UUID(), title: "Chat with Good Rudi", lastUsedISO8601: "2025-08-29T10:12:00Z", lastMessageContent: "Thanks for the help with the project! This was really useful and I learned a lot from our conversation."),
                ChatSession(id: UUID(), title: "Conversation name", lastUsedISO8601: "2025-09-01T08:00:00Z", lastMessageContent: "Can you explain how this works?"),
                ChatSession(id: UUID(), title: "Weekend plans", lastUsedISO8601: "2025-07-15T18:30:00Z", lastMessageContent: "Let's meet at the coffee shop at 2pm on Saturday")
            ]
            sessionsVM.isLoadingSessions = false
            sessionsVM.pendingRequests = []
            self.navigationViewModel = navVM
            self.sessionsViewModel = sessionsVM
        }
        var body: some View {
            SlideOutSidebarView(isOpen: .constant(true), profileNamespace: ns)
                .environmentObject(navigationViewModel)
                .environmentObject(sessionsViewModel)
                .environmentObject(LinkViewModel(accessTokenProvider: { "" }))
        }
    }
    return PreviewNoPending()
}