import SwiftUI
import PhotosUI
import UIKit

struct SlideOutSidebarContainerView<Content: View>: View {

    @StateObject private var navigationViewModel = SidebarNavigationViewModel()
    @StateObject private var sessionsViewModel = ChatSessionsViewModel()

    @Namespace private var profileNamespace

    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var linkVM: LinkViewModel

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var linkedMonthYear: String? {
        switch linkVM.state {
        case .linked:
            if let date = linkVM.linkedAt {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: date)
            }
            return nil
        default:
            return nil
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let blurIntensity: CGFloat = {
                let widthD = Double(width)
                if navigationViewModel.isOpen {
                    let dragProgress = abs(Double(navigationViewModel.dragOffset)) / max(widthD, 1.0)
                    let value = max(0.0, 10.0 - (dragProgress * 20.0))
                    return CGFloat(value)
                } else {
                    let dragProgress = Double(navigationViewModel.dragOffset) / max(widthD, 1.0)
                    let value = min(abs(dragProgress) * 20.0, 10.0)
                    return CGFloat(value)
                }
            }()

            ZStack {
                // Main Content - slides completely off screen when sidebar is open
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: navigationViewModel.isOpen ? width + navigationViewModel.dragOffset : max(0, navigationViewModel.dragOffset))
                    .blur(radius: min(blurIntensity, 6))
                    // Faster response when toggling open/close, and tighter interactive spring while dragging
                    .animation(.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0), value: navigationViewModel.isOpen)
                    .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88, blendDuration: 0), value: navigationViewModel.dragOffset)

                // Slide-out Sidebar - slides in from left to fully replace main content
                // Compute sidebar offset once so we can position the edge blur exactly at the visible edge
                let sidebarOffsetX: CGFloat = navigationViewModel.isOpen ? navigationViewModel.dragOffset : (-width + max(0, navigationViewModel.dragOffset))

                SlidebarView(
                    isOpen: $navigationViewModel.isOpen,
                    profileNamespace: profileNamespace
                )
                .offset(x: sidebarOffsetX)
                .blur(radius: (navigationViewModel.showProfileOverlay || navigationViewModel.showSettingsOverlay) ? 8 : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0), value: navigationViewModel.isOpen)
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88, blendDuration: 0), value: navigationViewModel.dragOffset)



                // Profile Overlay on top of slide-out menu
                if navigationViewModel.showProfileOverlay {
                    ProfileOverlayView(
                        isPresented: $navigationViewModel.showProfileOverlay,
                        profileNamespace: profileNamespace,
                        linkedMonthYear: linkedMonthYear
                    )
                    // Keep a single animation driver to avoid freeze during matchedGeometry
                    .transition(.opacity)
                    .animation(.spring(response: 0.32, dampingFraction: 0.92, blendDuration: 0), value: navigationViewModel.showProfileOverlay)
                }

                // Settings Overlay on top of slide-out menu
                if navigationViewModel.showSettingsOverlay {
                    SettingsOverlayView(
                        isPresented: $navigationViewModel.showSettingsOverlay,
                        profileNamespace: profileNamespace
                    )
                    .transition(.opacity)
                    .zIndex(2) // ensure above emblem to avoid ghosting on fast dismiss
                    .animation(.spring(response: 0.42, dampingFraction: 0.92, blendDuration: 0), value: navigationViewModel.showSettingsOverlay)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !navigationViewModel.showProfileOverlay && !navigationViewModel.showSettingsOverlay else { return }
                        // Clamp to reduce layout thrash on rapid drags
                        let clamped = max(min(value.translation.width, width), -width)
                        navigationViewModel.handleDragGesture(clamped, width: width)
                    }
                    .onEnded { value in
                        guard !navigationViewModel.showProfileOverlay && !navigationViewModel.showSettingsOverlay else { return }
                        navigationViewModel.handleSwipeGesture(value.translation.width, velocity: value.velocity.width, width: width)
                    }
            )
        }
        .environmentObject(navigationViewModel)
        .environmentObject(sessionsViewModel)
        .onAppear {
            sessionsViewModel.startObserving()
            navigationViewModel.dragOffset = 0
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive, .background:
                // Ensure no residual drag offset when app goes to background/recent apps
                withAnimation(nil) { navigationViewModel.dragOffset = 0 }
            case .active:
                // Reset any leftover offset immediately (no animation) and refresh data
                withAnimation(nil) { navigationViewModel.dragOffset = 0 }
                Task { await sessionsViewModel.refreshSessions() }
            @unknown default:
                withAnimation(nil) { navigationViewModel.dragOffset = 0 }
            }
        }
        // Deprecated in favor of in-place overlay
        .sheet(isPresented: $navigationViewModel.showSettingsSheet) {
            SettingsView()
        }
        .sheet(isPresented: $navigationViewModel.showLinkSheet) {
            MainLinkView(viewModel: linkVM)
        }
    }
}

#Preview {
    SlideOutSidebarContainerView {
        Text("Main Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.1))
    }
    .environmentObject(LinkViewModel(accessTokenProvider: {
        // Mock access token for preview
        return "mock-access-token"
    }))
}

// MARK: - Profile Overlay View
private struct ProfileOverlayView: View {

    @Binding var isPresented: Bool
    let profileNamespace: Namespace.ID
    let linkedMonthYear: String?

    @State private var showContent = false
    @State private var showingAvatarSelection = false
    @State private var showCards = false
    @State private var showTogetherCapsule = false

    private let data: ProfileData = ProfileData.load()

    var body: some View {
        ZStack {
            // Foreground content (everything scrolls together; nothing overlaid on top)
            VStack(spacing: 0) {
                // All content scrolls together (X, avatars, cards)
                ScrollView {
                    VStack(spacing: 16) {
                        // Close button at very top so it scrolls away too
                        HStack {
                            Spacer()
                            Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { isPresented = false } }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }

                        // Animated avatars at top, positioned higher
                        ZStack {
                            // Partner (behind)
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
                                .frame(width: 84, height: 84)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                )
                                .overlay(
                                    Text("S")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 30)
                                .matchedGeometryEffect(id: "avatarPartner", in: profileNamespace)

                            // User (front)
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
                                .frame(width: 84, height: 84)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                )
                                .overlay(
                                    Text("M")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                )
                                .offset(x: -30)
                                .matchedGeometryEffect(id: "avatarUser", in: profileNamespace)
                        }
                        .padding(.top, -24)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        // Together since capsule near avatars (appears with cards when linked)
                        if showTogetherCapsule, let monthYear = linkedMonthYear {
                            HStack {
                                Spacer(minLength: 0)
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                        .font(.system(size: 12))
                                    Text("Together since \(monthYear)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.12), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                                )
                                Spacer(minLength: 0)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if showCards {
                            // Edit Avatars capsule centered
                            HStack {
                                Spacer(minLength: 0)
                                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showingAvatarSelection = true } }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.2.circle")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                        Text("Edit Avatars")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray6))
                                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.12), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer(minLength: 0)
                            }

                            PremiumStatsCardsView(viewModel: PremiumStatsViewModel(), stats: data.profileStats)

                            RelationshipInsightsSectionView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .background(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .padding(.bottom, 12)
            .overlay(alignment: .top) { StatusBarBackground(showsDivider: false) }
            .onAppear {
                showTogetherCapsule = false
                showCards = false
                // Reveal content only after avatar matchedGeometry animation settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(
                        .spring(response: 0.28, dampingFraction: 0.94)
                    ) {
                        showTogetherCapsule = true
                        showCards = true
                    }
                }
            }
            .overlay(
                Group {
                    if showingAvatarSelection {
                        ZStack {
                            Color.black.opacity(0.1)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.25)) { showingAvatarSelection = false }
                                }
                            VStack(spacing: 12) {
                                HStack {
                                    Spacer()
                                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showingAvatarSelection = false } }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .padding(8)
                                            .background(.ultraThinMaterial, in: Circle())
                                    }
                                }
                                .padding(.top, 4)

                                SettingsAvatarPickerView(viewModel: SettingsViewModel())
                                    .frame(maxWidth: 520)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
                            )
                            .padding(.horizontal, 24)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                ))
                        }
                        .animation(.easeInOut(duration: 0.25), value: showingAvatarSelection)
                    }
                }
            )
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.92, blendDuration: 0), value: isPresented)
    }
}

// (Metal overlay removed)

// MARK: - Settings Overlay View
private struct SettingsOverlayView: View {

    @Binding var isPresented: Bool
    let profileNamespace: Namespace.ID

    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var linkVM: LinkViewModel

    @State private var showCards = false
    @State private var showSubtitleCapsule = false

    var body: some View {
        ZStack {
            // Foreground content matching profile overlay behavior
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Close button
                        HStack {
                            Spacer()
                            Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { isPresented = false } }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }

                        // Animated settings emblem
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
                                .frame(width: 84, height: 84)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                )
                                .matchedGeometryEffect(id: "settingsEmblem", in: profileNamespace)

                            Image(systemName: "gearshape")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.white)
                                .matchedGeometryEffect(id: "settingsGearIcon", in: profileNamespace)
                        }
                        .padding(.top, -24)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        // Subtitle capsule
                        if showSubtitleCapsule {
                            HStack {
                                Spacer(minLength: 0)
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.3")
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                        .font(.system(size: 12))
                                    Text("Customize your experience")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.12), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                                )
                                Spacer(minLength: 0)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if showCards {
                            // Render settings sections as premium cards
                            VStack(spacing: 24) {
                                ForEach(Array(viewModel.settingsSections.enumerated()), id: \.offset) { sectionIndex, section in
                                    SettingsCardView(
                                        section: section,
                                        onToggle: { settingIndex in
                                            viewModel.toggleSetting(for: sectionIndex, settingIndex: settingIndex)
                                        },
                                        onAction: { settingIndex in
                                            viewModel.handleSettingAction(for: sectionIndex, settingIndex: settingIndex)
                                        },
                                        onPickerSelect: { settingIndex, value in
                                            viewModel.handlePickerSelection(for: sectionIndex, settingIndex: settingIndex, value: value)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .background(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .navigationDestination(item: $viewModel.destination) { destination in
                    switch destination {
                    case .link:
                        MainLinkView(viewModel: linkVM)
                            .navigationTitle("Link Your Partner")
                            .navigationBarTitleDisplayMode(.inline)
                    case .appearance:
                        AppearancePickerView(
                            current: {
                                let value = viewModel.currentAppearance
                                if value == "Light" { return .light }
                                if value == "Dark" { return .dark }
                                return .system
                            }(),
                            onSelect: { option in
                                viewModel.selectAppearance(option.rawValue)
                            }
                        )
                    case .avatar:
                        SettingsAvatarPickerView(viewModel: viewModel)
                            .navigationTitle("Change Avatar")
                            .navigationBarTitleDisplayMode(.inline)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .background(Color(.systemBackground).ignoresSafeArea())
        .overlay(alignment: .top) { StatusBarBackground(showsDivider: false) }
        .onAppear {
            showSubtitleCapsule = false
            showCards = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                    showSubtitleCapsule = true
                    showCards = true
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0), value: isPresented)
    }
}