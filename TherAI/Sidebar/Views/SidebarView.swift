import SwiftUI

struct SlideOutSidebarView: View {

    @EnvironmentObject private var viewModel: SlideOutSidebarViewModel

    @Binding var selectedTab: SidebarTab
    @Binding var isOpen: Bool


    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Settings button in top left
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.showSettingsSheet = true
                    }
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                }

                Spacer()

                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
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
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
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
                
                // Sessions Section (expandable list of sessions)
                SectionHeader(title: "Sessions", isExpanded: viewModel.isChatsExpanded) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.isChatsExpanded.toggle()
                    }
                }

                if viewModel.isChatsExpanded {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if !viewModel.sessions.isEmpty {
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
                                    .contextMenu {
                                        Button(action: {
                                            viewModel.startRename(sessionId: session.id, currentTitle: session.title)
                                        }) {
                                            Label("Rename", systemImage: "pencil")
                                        }
                                        
                                        Button(action: {
                                            print("🔥 Delete button pressed for session: \(session.id)")
                                            // Test immediate UI update first
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                viewModel.sessions.removeAll { $0.id == session.id }
                                            }
                                            // Then try backend deletion
                                            Task {
                                                await viewModel.deleteSession(session.id)
                                            }
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } else {
                                // Minimalistic empty state
                                VStack(spacing: 16) {
                                    Image(systemName: "message")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundColor(.secondary)
                                    
                                    Text("No sessions yet")
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
                    .onAppear {
                        // Clear and reload sessions when sidebar appears to ensure we have latest from backend
                        Task {
                            await viewModel.clearAndReloadSessions()
                        }
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
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.showProfileSheet = true
                    }
                }) {
                    GrokStyleProfileButton()
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.purple.opacity(0.5),
                                            Color.blue.opacity(0.45),
                                            Color.cyan.opacity(0.4)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: Color.purple.opacity(0.25), radius: 20, x: 0, y: 10)
                        .shadow(color: Color.cyan.opacity(0.2), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 0)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .alert("Rename Chat", isPresented: $viewModel.showRenameDialog) {
            TextField("Chat name", text: $viewModel.renameText)
            Button("Cancel", role: .cancel) {
                viewModel.cancelRename()
            }
            Button("Rename") {
                viewModel.confirmRename()
            }
        } message: {
            Text("Enter a new name for this chat")
        }
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
    var body: some View {
        HStack(spacing: 24) {
            // Two overlapping profile circles (Grok style)
            ZStack {
                // Partner profile circle (behind, slightly offset)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.98, green: 0.45, blue: 0.7), Color(red: 0.85, green: 0.35, blue: 0.6)],
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
                    .offset(x: 20, y: 0)

                // User profile circle (in front)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.25, green: 0.7, blue: 1.0), Color(red: 0.12, green: 0.55, blue: 0.92)],
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
                    .offset(x: -20, y: 0)
            }

            // Names with connection symbol
            HStack(spacing: 8) {
                Text("Marcus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text("&")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text("Sarah")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 50)
        .padding(.trailing, 32)
        .padding(.vertical, 20)
    }
}

#Preview {
    SlideOutSidebarView(selectedTab: .constant(.chat), isOpen: .constant(true))
        .environmentObject(SlideOutSidebarViewModel())
}
