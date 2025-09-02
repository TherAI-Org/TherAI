import SwiftUI

struct SlideOutSidebarView: View {

    @EnvironmentObject private var viewModel: SlideOutSidebarViewModel

    @Binding var selectedTab: SidebarTab
    @Binding var isOpen: Bool

    @State private var notificationsExpansionProgress: CGFloat = 0
    @State private var notificationsExpandedContentHeight: CGFloat = 0
    @State private var chatsExpansionProgress: CGFloat = 0
    @State private var chatsExpandedContentHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.showProfileSheet = true
                    }
                }) {
                    Image(systemName: "person")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.startNewChat()
                        viewModel.isChatsExpanded = true
                        selectedTab = .chat
                        isOpen = false
                    }
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Sections
            VStack(spacing: 10) {
                // Notifications Section (expandable, no data yet)
                SectionHeader(title: "Notifications", isExpanded: viewModel.isNotificationsExpanded) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.isNotificationsExpanded.toggle()
                    }
                }

                if viewModel.isNotificationsExpanded {
                    VStack(spacing: 6) {
                        Text("No notifications from your partner yet...")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                            .padding(.top, -4)
                    }
                }

                // Chats Section (expandable list of sessions)
                SectionHeader(title: "Chats", isExpanded: viewModel.isChatsExpanded) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                        viewModel.isChatsExpanded.toggle()
                    }
                }

                if viewModel.isChatsExpanded && !viewModel.sessions.isEmpty {
                    ZStack(alignment: .top) {
                        VStack(spacing: 8) {
                            ForEach(Array(viewModel.sessions.enumerated()), id: \.offset) { index, session in
                                let count = max(1, viewModel.sessions.count)
                                let step = 1.0 / CGFloat(count)
                                let start = CGFloat(index) * step
                                let rowProgress = max(0, min(1, (chatsExpansionProgress - start) / step))

                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                        viewModel.openSession(session.id)
                                        selectedTab = .chat
                                        isOpen = false
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "message")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text(session.title ?? "Chat")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(.systemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .opacity(rowProgress)
                                .offset(x: 0, y: (1 - rowProgress) * 8)
                                .animation(.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0.05), value: rowProgress)
                            }
                        }
                    }
                    .frame(height: chatsExpandedContentHeight * chatsExpansionProgress, alignment: .top)
                    .clipped()
                    .background(
                        VStack(spacing: 8) {
                            ForEach(viewModel.sessions) { session in
                                HStack(spacing: 10) {
                                    Image(systemName: "message")
                                        .font(.system(size: 16, weight: .medium))
                                    Text(session.title ?? "Chat")
                                        .font(.system(size: 16, weight: .regular))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .overlay(
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear {
                                        let h = proxy.size.height
                                        if abs(h - chatsExpandedContentHeight) > 0.5 {
                                            chatsExpandedContentHeight = h
                                        }
                                    }
                                    .onChange(of: viewModel.isChatsExpanded) { _, _ in
                                        let h = proxy.size.height
                                        if abs(h - chatsExpandedContentHeight) > 0.5 {
                                            chatsExpandedContentHeight = h
                                        }
                                    }
                                    .onChange(of: viewModel.sessions) { _, _ in
                                        let h = proxy.size.height
                                        if abs(h - chatsExpandedContentHeight) > 0.5 {
                                            chatsExpandedContentHeight = h
                                        }
                                    }
                            }
                        )
                    )
                } else if viewModel.isChatsExpanded {
                    // No animation for empty chats list
                    EmptyView()
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)

            Spacer()

            VStack(spacing: 16) {
                Text("More features coming soon...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 5, y: 0)
        .onAppear {
            notificationsExpansionProgress = viewModel.isNotificationsExpanded ? 1 : 0
            chatsExpansionProgress = viewModel.isChatsExpanded ? 1 : 0
        }
        .onChange(of: viewModel.isNotificationsExpanded) { _, newVal in
            if newVal {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)) {
                    notificationsExpansionProgress = 1
                }
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.1)) {
                    notificationsExpansionProgress = 0
                }
            }
        }
        .onChange(of: viewModel.isChatsExpanded) { _, newVal in
            if newVal {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.05)) {
                    chatsExpansionProgress = 1
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0.05)) {
                    chatsExpansionProgress = 0
                }
            }
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Profile Picture View
struct ProfilePictureView: View {
    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)

            // White border
            Circle()
                .fill(.white)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            // Main avatar with blue gradient (matching profile screen)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Text("M")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
        }
    }
}

struct SidebarItemView: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Keep the old SidebarView for backward compatibility if needed
struct SidebarView: View {
    @Binding var selectedTab: Tab
    @State private var isExpanded = false

    enum Tab {
        case chat
        case profile
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Text("TherAI")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "sidebar.right" : "sidebar.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }

                Divider()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Navigation Items
            VStack(spacing: 8) {
                SidebarItemView(
                    title: "Chat",
                    icon: "message.fill",
                    isSelected: selectedTab == .chat
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .chat
                    }
                }

                SidebarItemView(
                    title: "Profile",
                    icon: "person.fill",
                    isSelected: selectedTab == .profile
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .profile
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)

            Spacer()
        }
        .frame(width: isExpanded ? 250 : 80)
        .background(Color(.systemBackground))

    }
}

#Preview {
    SlideOutSidebarView(selectedTab: .constant(.chat), isOpen: .constant(true))
        .environmentObject(SlideOutSidebarViewModel())
}
