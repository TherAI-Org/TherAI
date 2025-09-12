import SwiftUI

// MARK: - PendingRequestRow Component
struct PendingRequestRow: View {
    let request: DialogueViewModel.DialogueRequest

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("Partner Request")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                Text(request.requestContent)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

struct SlideOutSidebarView: View {

    @EnvironmentObject private var viewModel: SlideOutSidebarViewModel

    @Binding var selectedTab: SidebarTab
    @Binding var isOpen: Bool

    let profileNamespace: Namespace.ID


    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Settings button in top left
                Button(action: {
                    Haptics.impact(.medium)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
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

                Spacer()

                Button(action: {
                    Haptics.impact(.medium)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        isOpen = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Divider()
                .padding(.horizontal, 16)

            // Sections
            VStack(spacing: 10) {
                // New Conversation Button
                Button(action: {
                    Haptics.impact(.medium)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.startNewChat()
                        viewModel.isChatsExpanded = true
                        selectedTab = .chat
                        isOpen = false
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        Text("New Conversation")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                // Pending Requests Section (always visible)
                SectionHeader(title: "Pending Requests", isExpanded: viewModel.isNotificationsExpanded) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.isNotificationsExpanded.toggle()
                    }
                }

                if viewModel.isNotificationsExpanded {
                    if viewModel.pendingRequests.isEmpty {
                        // Show empty state
                        HStack {
                            Text("No pending requests")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(viewModel.pendingRequests) { request in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                        viewModel.openPendingRequest(request)
                                        isOpen = false
                                    }
                                }) {
                                    PendingRequestRow(request: request)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Chats Section (expandable list of sessions)
                SectionHeader(title: "Chats", isExpanded: viewModel.isChatsExpanded) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.isChatsExpanded.toggle()
                    }
                }

                if viewModel.isChatsExpanded {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if viewModel.isLoadingSessions {
                                VStack(spacing: 16) {
                                    ProgressView()
                                    Text("Loading sessions…")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 40)
                            } else if !viewModel.sessions.isEmpty {
                                ForEach(viewModel.sessions, id: \.id) { session in
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                            viewModel.openSession(session.id)
                                            selectedTab = .chat
                                            isOpen = false
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "message")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                            Text(session.title ?? "Session")
                                                .font(.system(size: 16, weight: .regular))
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    // Context menu removed (rename/delete disabled)
                                }
                            } else {
                                // Minimalistic empty state
                                VStack(spacing: 16) {
                                    Image(systemName: "message")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundColor(.secondary)

                                    Text("No chats yet")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 40)
                            }
                        }
                        .padding(.horizontal, 0)
                    }
                    .refreshable {
                        await viewModel.refreshSessions()
                    }
                    .frame(maxHeight: 300) // Limit height to prevent taking up too much space
                    .background(Color.clear)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)

            Spacer()

            // Grok-style profile button at bottom bottom of screen
            VStack(spacing: 0) {
                Button(action: {
                    Haptics.impact(.medium)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0)) {
                        viewModel.showProfileOverlay = true
                    }
                }) {
                    GrokStyleProfileButton(profileNamespace: profileNamespace)
                }
                .buttonStyle(PlainButtonStyle())
                // GPU overlay currently falls back when start frame is unavailable
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 0)
            .padding(.bottom, 0)
            .offset(y: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Section Header
private struct SectionHeader: View {
    let title: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // No background for minimalist, Grok-like look
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Grok Style Profile Button
struct GrokStyleProfileButton: View {
    let profileNamespace: Namespace.ID

    var body: some View {
        HStack {
            // Align avatars towards left, but not fully flush to edge
            // Two overlapping profile circles
            ZStack {
                // Partner profile circle (behind, slightly offset)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.72, green: 0.37, blue: 0.98),
                                Color(red: 0.38, green: 0.65, blue: 1.00)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                    .overlay(
                        Text("S")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )
                    .offset(x: 20)
                    .matchedGeometryEffect(id: "avatarPartner", in: profileNamespace)

                // User profile circle (in front)
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
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                    .overlay(
                        Text("M")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )
                    .offset(x: -20)
                    .matchedGeometryEffect(id: "avatarUser", in: profileNamespace)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 40)
        .padding(.trailing, 18)
        .padding(.vertical, 20)
    }
}

struct SlideOutSidebarView_Previews: PreviewProvider {
    @Namespace static var ns
    static var previews: some View {
        SlideOutSidebarView(selectedTab: .constant(.chat), isOpen: .constant(true), profileNamespace: ns)
            .environmentObject(SlideOutSidebarViewModel())
    }
}
