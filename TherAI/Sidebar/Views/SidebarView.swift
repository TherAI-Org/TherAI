import SwiftUI

struct SlideOutSidebarView: View {

    @EnvironmentObject private var viewModel: SlideOutSidebarViewModel
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTab: SidebarTab
    @Binding var isOpen: Bool

    @FocusState private var isSearchFocused: Bool

    @State private var isSearching: Bool = false
    @State private var searchText: String = ""

    let profileNamespace: Namespace.ID

    private func formatLastUsed(_ iso: String?) -> String {
        guard let raw = iso?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return "" }

        // 1) Try ISO8601 with and without fractional seconds
        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]

        let parsed = iso1.date(from: raw) ?? iso2.date(from: raw)
        guard let date = parsed else { return "" }

        let out = DateFormatter()
        out.locale = Locale.current
        out.dateFormat = "dd.MM.yyyy"
        return out.string(from: date)
    }

    var body: some View {
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
                    LinearGradient(
                        colors: [
                            Color(white: colorScheme == .dark ? 0.14 : 0.945),
                            Color(white: colorScheme == .dark ? 0.17 : 0.965)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                .clipShape(Capsule())
                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    isSearching = true
                    isSearchFocused = true
                }
                Spacer().frame(width: 16)

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
                            viewModel.startNewChat()
                            selectedTab = .chat
                            isOpen = false
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

                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
            .padding(.vertical, 8)
            .padding(.top, 8)
            .onChange(of: isSearchFocused) { old, newVal in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { isSearching = newVal }
            }

            ScrollView {
                VStack(spacing: 10) {

                    let hasPending = !viewModel.pendingRequests.isEmpty

                    if hasPending {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.pendingRequests) { request in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                        viewModel.openPendingRequest(request)
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

                    if hasPending {
                        Divider()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }

                    let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let lower = term.lowercased()
                    let filteredSessions = viewModel.sessions.filter { session in
                        if lower.isEmpty { return true }
                        return (session.title ?? "Session").lowercased().contains(lower)
                    }

                    if lower.isEmpty {
                        HStack(spacing: 12) {
                            Text("Conversations")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        LazyVStack(spacing: 6) {
                            if viewModel.isLoadingSessions {
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
                                            viewModel.openSession(session.id)
                                            selectedTab = .chat
                                            isOpen = false
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(session.title ?? "Session")
                                                .font(.system(size: 18, weight: .regular))
                                                .foregroundColor(.primary)
                                            Text(formatLastUsed(session.lastUsedISO8601))
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { await viewModel.deleteSession(session.id) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    } else {
                        if !term.isEmpty {
                            HStack {
                                Text("\(filteredSessions.count) results for \"\(term)\"")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        }

                        LazyVStack {
                            if !filteredSessions.isEmpty {
                                ForEach(filteredSessions, id: \.id) { session in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                            viewModel.openSession(session.id)
                                            selectedTab = .chat
                                            isOpen = false
                                            isSearching = false
                                            isSearchFocused = false
                                        }
                                    }) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(session.title ?? "Session")
                                                .font(.system(size: 17, weight: .regular))
                                                .foregroundColor(.primary)
                                            Text(formatLastUsed(session.lastUsedISO8601))
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            } else {
                                HStack {
                                    Text("No results")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .refreshable {
                await viewModel.refreshSessions()
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
                 Button(action: {
                     Haptics.impact(.medium)
                     withAnimation(.spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0)) {
                         viewModel.showProfileOverlay = true
                     }
                 }) {
                     ProfileButtonView(profileNamespace: profileNamespace, compact: true)
                 }
                 .buttonStyle(PlainButtonStyle())

                 Spacer()

                 // Settings on lower right
                 Button(action: {
                     Haptics.impact(.medium)
                     withAnimation(.spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0)) {
                         viewModel.showSettingsOverlay = true
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
                 }
                 .buttonStyle(PlainButtonStyle())
             }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
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
         .ignoresSafeArea(edges: .bottom)
         .ignoresSafeArea(.keyboard, edges: .bottom)
     }
    }
}

#Preview("Pending Requests") {
    struct PreviewWithPending: View {
        @Namespace var ns
        let viewModel: SlideOutSidebarViewModel
        init() {
            let vm = SlideOutSidebarViewModel()
            vm.sessions = [
                ChatSession(id: UUID(), title: "Chat with Good Rudi", lastUsedISO8601: "2025-08-29T10:12:00Z"),
                ChatSession(id: UUID(), title: "Conversation name", lastUsedISO8601: "2025-09-01T08:00:00Z"),
                ChatSession(id: UUID(), title: "Weekend plans", lastUsedISO8601: "2025-07-15T18:30:00Z")
            ]
            vm.isLoadingSessions = false
            // Seed example pending requests
            vm.pendingRequests = [
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
            self.viewModel = vm
        }
        var body: some View {
            SlideOutSidebarView(selectedTab: .constant(.chat), isOpen: .constant(true), profileNamespace: ns)
                .environmentObject(viewModel)
        }
    }
    return PreviewWithPending()
}

#Preview("Default") {
    struct PreviewNoPending: View {
        @Namespace var ns
        let viewModel: SlideOutSidebarViewModel
        init() {
            let vm = SlideOutSidebarViewModel()
            vm.sessions = [
                ChatSession(id: UUID(), title: "Chat with Good Rudi", lastUsedISO8601: "2025-08-29T10:12:00Z"),
                ChatSession(id: UUID(), title: "Conversation name", lastUsedISO8601: "2025-09-01T08:00:00Z"),
                ChatSession(id: UUID(), title: "Weekend plans", lastUsedISO8601: "2025-07-15T18:30:00Z")
            ]
            vm.isLoadingSessions = false
            vm.pendingRequests = []
            self.viewModel = vm
        }
        var body: some View {
            SlideOutSidebarView(selectedTab: .constant(.chat), isOpen: .constant(true), profileNamespace: ns)
                .environmentObject(viewModel)
        }
    }
    return PreviewNoPending()
}
