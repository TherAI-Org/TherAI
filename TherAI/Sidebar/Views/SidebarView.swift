import SwiftUI

struct SlideOutSidebarView: View {

    @EnvironmentObject private var viewModel: SlideOutSidebarViewModel

    @Binding var selectedTab: SidebarTab
    @Binding var isOpen: Bool

    let profileNamespace: Namespace.ID
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isSearching: Bool = false

    // MARK: - Date formatting
    private func formatLastUsed(_ iso: String?) -> String {
        guard let iso = iso else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        if let date = formatter.date(from: iso) ?? fallback.date(from: iso) {
            let df = DateFormatter()
            df.locale = Locale.current
            df.dateFormat = "dd.MM.yyyy"
            return df.string(from: date)
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search", text: $searchText)
                        .font(.system(size: 16))
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .focused($isSearchFocused)
                        .onTapGesture { isSearching = true }
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; isSearchFocused = true }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
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
                        Haptics.impact(.light)
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
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .padding(.top, 10)
            .onChange(of: isSearchFocused) { old, newVal in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { isSearching = newVal }
            }

            ZStack(alignment: .top) {
                VStack(spacing: 10) {

                VStack(alignment: .leading, spacing: 12) {


                    let requests = viewModel.pendingRequests
                    if requests.isEmpty {
                        // Placeholder futuristic cards
                        let placeholders = [
                            "Partner request: Share chat access?",
                            "Invite from S: Connect for dialogue session"
                        ]
                        ForEach(placeholders, id: \.self) { text in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Partner Request")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(text)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
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
                    } else {
                        ForEach(requests) { request in
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
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 16)

                Divider()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let showingSearchHeader = false
                let filteredSessions = viewModel.sessions.filter { session in
                    let lower = term.lowercased()
                    if lower.isEmpty { return true }
                    return (session.title ?? "Session").lowercased().contains(lower)
                }

                HStack(spacing: 12) {
                    if showingSearchHeader {
                        Text("\(filteredSessions.count) results for \"\(term)\"")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Conversations")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView {
                    LazyVStack(spacing: 4) {
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
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.primary)
                                        Text(formatLastUsed(session.lastUsedISO8601))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
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
                } else if showingSearchHeader {
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
                    .padding(.horizontal, 0)
                }
                .refreshable {
                    await viewModel.refreshSessions()
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 300)
                .background(Color.clear)
                .padding(.top, 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .opacity(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
            .padding(.top, 8)

            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                let filtered = viewModel.sessions.filter { session in
                    let lower = term.lowercased()
                    if lower.isEmpty { return false }
                    return (session.title ?? "Session").lowercased().contains(lower)
                }
                VStack(spacing: 0) {
                    if !term.isEmpty {
                        HStack {
                            Text("\(filtered.count) results for \"\(term)\"")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if !filtered.isEmpty {
                                ForEach(filtered, id: \.id) { session in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                            viewModel.openSession(session.id)
                                            selectedTab = .chat
                                            isOpen = false
                                            isSearching = false
                                            isSearchFocused = false
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                            Text(session.title ?? "Session")
                                                .font(.system(size: 16))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 0)
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.systemBackground))
            }

            }
            // End ZStack (search vs content)

            Spacer()

            HStack {
                // Profile circles on lower left
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)


        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    struct PreviewContent: View {
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
            self.viewModel = vm
        }
        var body: some View {
            SlideOutSidebarView(selectedTab: .constant(.chat), isOpen: .constant(true), profileNamespace: ns)
                .environmentObject(viewModel)
        }
    }
    return PreviewContent()
}
