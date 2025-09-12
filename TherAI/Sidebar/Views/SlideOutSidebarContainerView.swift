import SwiftUI
import UIKit

struct SlideOutSidebarContainerView<Content: View>: View {

    @StateObject private var viewModel = SlideOutSidebarViewModel()
    @Namespace private var profileNamespace

    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var linkVM: LinkViewModel

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let blurIntensity: CGFloat = {
                let widthD = Double(width)
                if viewModel.isOpen {
                    let dragProgress = abs(Double(viewModel.dragOffset)) / max(widthD, 1.0)
                    let value = max(0.0, 10.0 - (dragProgress * 20.0))
                    return CGFloat(value)
                } else {
                    let dragProgress = Double(viewModel.dragOffset) / max(widthD, 1.0)
                    let value = min(abs(dragProgress) * 20.0, 10.0)
                    return CGFloat(value)
                }
            }()
            ZStack {
                // Main Content - slides completely off screen when sidebar is open
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: viewModel.isOpen ? width + viewModel.dragOffset : viewModel.dragOffset)
                    .blur(radius: min(blurIntensity, 6))
                    .animation(.spring(response: 0.32, dampingFraction: 0.92, blendDuration: 0), value: viewModel.isOpen)
                    .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.9, blendDuration: 0), value: viewModel.dragOffset)

                // Slide-out Sidebar - slides in from left to fully replace main content
                SlideOutSidebarView(
                    selectedTab: $viewModel.selectedTab,
                    isOpen: $viewModel.isOpen,
                    profileNamespace: profileNamespace
                )
                .offset(x: viewModel.isOpen ? viewModel.dragOffset : -width + viewModel.dragOffset)
                .blur(radius: (viewModel.showProfileOverlay || viewModel.showSettingsOverlay) ? 8 : 0)
                .animation(.spring(response: 0.32, dampingFraction: 0.92, blendDuration: 0), value: viewModel.isOpen)
                .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.9, blendDuration: 0), value: viewModel.dragOffset)

                // Profile Overlay on top of slide-out menu
                if viewModel.showProfileOverlay {
                    ProfileOverlayView(
                        isPresented: $viewModel.showProfileOverlay,
                        profileNamespace: profileNamespace
                    )
                    // Keep a single animation driver to avoid freeze during matchedGeometry
                    .transition(.opacity)
                    .animation(.spring(response: 0.32, dampingFraction: 0.92, blendDuration: 0), value: viewModel.showProfileOverlay)
                }

                // Settings Overlay on top of slide-out menu
                if viewModel.showSettingsOverlay {
                    SettingsOverlayView(
                        isPresented: $viewModel.showSettingsOverlay,
                        profileNamespace: profileNamespace
                    )
                    .transition(.opacity)
                    .zIndex(2) // ensure above emblem to avoid ghosting on fast dismiss
                    .animation(.spring(response: 0.42, dampingFraction: 0.92, blendDuration: 0), value: viewModel.showSettingsOverlay)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !viewModel.showProfileOverlay && !viewModel.showSettingsOverlay else { return }
                        // Clamp to reduce layout thrash on rapid drags
                        let clamped = max(min(value.translation.width, width), -width)
                        viewModel.handleDragGesture(clamped, width: width)
                    }
                    .onEnded { value in
                        guard !viewModel.showProfileOverlay && !viewModel.showSettingsOverlay else { return }
                        viewModel.handleSwipeGesture(value.translation.width, velocity: value.velocity.width, width: width)
                    }
            )
        }
        .environmentObject(viewModel)
        .onAppear {
            viewModel.startObserving()
            viewModel.dragOffset = 0
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive, .background:
                // Ensure no residual drag offset when app goes to background/recent apps
                withAnimation(nil) { viewModel.dragOffset = 0 }
            case .active:
                // Reset any leftover offset immediately (no animation) and refresh data
                withAnimation(nil) { viewModel.dragOffset = 0 }
                Task { await viewModel.refreshSessions() }
            @unknown default:
                withAnimation(nil) { viewModel.dragOffset = 0 }
            }
        }
        // Deprecated in favor of in-place overlay
        .sheet(isPresented: $viewModel.showSettingsSheet) {
            SettingsView()
        }
        .sheet(isPresented: $viewModel.showLinkSheet) {
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
    .environmentObject(SlideOutSidebarViewModel())
}

// MARK: - Profile Overlay View
private struct ProfileOverlayView: View {

    @Binding var isPresented: Bool
    let profileNamespace: Namespace.ID

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

                        // Together since capsule near avatars (appears with cards)
                        if showTogetherCapsule {
                            HStack {
                                Spacer(minLength: 0)
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                        .font(.system(size: 12))
                                    Text("Together since \(data.relationshipHeader.relationshipStartMonthYear)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemBackground))
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
                            // Edit Avatars chip-sized card
                            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showingAvatarSelection = true } }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.2.circle")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Edit Avatars")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.12), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

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
                showingAvatarSelection ?
                ZStack {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) { showingAvatarSelection = false }
                        }
                    AvatarSelectionView(isPresented: $showingAvatarSelection)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
                .animation(.easeInOut(duration: 0.25), value: showingAvatarSelection)
                : nil
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
                                        .fill(Color(.systemBackground))
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

// MARK: - Dialogue Panel View (right-side)
// Dialogue panel view removed; ChatView already provides dialogue mode
