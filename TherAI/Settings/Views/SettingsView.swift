import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    let profileNamespace: Namespace.ID

    @StateObject private var viewModel = SettingsViewModel()
    // Appearance controls removed; view follows app appearance
    @EnvironmentObject private var linkVM: LinkViewModel
    @EnvironmentObject private var sessionsVM: ChatSessionsViewModel

    @State private var showCards = false
    @State private var avatarRefreshKey = UUID()

    var body: some View {
        ZStack {
            // Foreground content matching profile overlay behavior
            NavigationStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Top gap
                        Color.clear
                            .frame(height: 20)

                        // User avatar (or settings emblem)
                        ZStack {
                            // Background: Always render saved avatar or default
                            AvatarCacheManager.shared.cachedAsyncImage(
                                urlString: sessionsVM.myAvatarURL,
                                placeholder: {
                                    AnyView(Color.clear)
                                },
                                fallback: {
                                    AnyView(
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
                                                Image(systemName: "gearshape")
                                                    .font(.system(size: 36, weight: .semibold))
                                                    .foregroundColor(.white)
                                            )
                                    )
                                }
                            )
                            .frame(width: 84, height: 84)
                            .clipShape(Circle())
                            .matchedGeometryEffect(id: sessionsVM.myAvatarURL != nil ? "settingsGearIcon" : "settingsEmblem", in: profileNamespace)
                            .id(avatarRefreshKey)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 12)

                        // User name and connection status
                        VStack(spacing: 8) {
                            // Prefer profile full name loaded from backend; fallback to auth metadata or email
                            let preferredName = !viewModel.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? viewModel.fullName : {
                                if let user = AuthService.shared.currentUser {
                                    if let n = user.userMetadata["full_name"]?.stringValue, !n.isEmpty { return n }
                                    if let n = user.userMetadata["name"]?.stringValue, !n.isEmpty { return n }
                                    if let email = user.email { return email.components(separatedBy: "@").first ?? "User" }
                                }
                                return "User"
                            }()
                            Text(preferredName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)

                            // Connection capsule (only show if connected)
                            if viewModel.isConnectedToPartner {
                                ConnectionCapsuleView(
                                    partnerName: viewModel.partnerName,
                                    partnerAvatarURL: viewModel.partnerAvatarURL
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                        }
                        .padding(.bottom, 24)


                        // Settings cards sections
                        if showCards {
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

                                // Version text at bottom
                                VStack(spacing: 0) {
                                    Text("VERSION 1.0.0")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .padding(.top, 20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .background(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            Haptics.impact(.light)
                            viewModel.showPersonalizationEdit = true
                        }) {
                            Text("Edit")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 8)
                                .frame(minWidth: 54, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            Haptics.impact(.light)
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationDestination(for: SettingsDestination.self) { dest in
                switch dest {
                case .link:
                    MainLinkView(accessTokenProvider: {
                        await AuthService.shared.getAccessToken() ?? ""
                    })
                    .navigationTitle("Link Partner")
                    .navigationBarTitleDisplayMode(.inline)
                case .contactSupport:
                    ContactSupportView()
                        .navigationTitle("Contact Support")
                        .navigationBarTitleDisplayMode(.inline)
                case .privacyPolicy:
                    PrivacyPolicyView()
                        .navigationTitle("Privacy Policy")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .navigationDestination(item: $viewModel.destination) { dest in
                switch dest {
                case .link:
                    MainLinkView(accessTokenProvider: {
                        await AuthService.shared.getAccessToken() ?? ""
                    })
                    .navigationTitle("Link Partner")
                    .navigationBarTitleDisplayMode(.inline)
                case .contactSupport:
                    ContactSupportView()
                        .navigationTitle("Contact Support")
                        .navigationBarTitleDisplayMode(.inline)
                case .privacyPolicy:
                    PrivacyPolicyView()
                        .navigationTitle("Privacy Policy")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $viewModel.showPersonalizationEdit) {
                PersonalizationEditView(
                    isPresented: $viewModel.showPersonalizationEdit,
                    profileNamespace: profileNamespace
                )
                .environmentObject(sessionsVM)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        // No view-level appearance logic anymore (follows app)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .animation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0), value: isPresented)
        .onAppear {
            showCards = false

            // Refresh connection status immediately
            viewModel.refreshConnectionStatus()
            // Preload partner avatar from cached URL for instant capsule image
            viewModel.preloadPartnerAvatarIfAvailable()

            // Preload avatar for personalization screen
            viewModel.preloadAvatar()

            // Load profile information
            viewModel.loadProfileInfo()

            // Apply any already-known partner info from sessions VM instantly
            viewModel.applyPartnerInfo(sessionsVM.partnerInfo)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                    showCards = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileChanged)) { _ in
            viewModel.loadProfileInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .avatarChanged)) { _ in
            avatarRefreshKey = UUID()
        }
        // Keep connection capsule synced with linking state changes
        .onChange(of: linkVM.state) { _, newState in
            // If linked, refresh from backend; otherwise clear immediately so capsule hides live
            if case .linked = newState {
                viewModel.refreshConnectionStatus()
            } else {
                viewModel.applyPartnerInfo(nil)
            }
        }
        // React to session-level partner info updates as a live source of truth
        .onReceive(sessionsVM.$partnerInfo) { newInfo in
            viewModel.applyPartnerInfo(newInfo)
        }
    }

}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @Namespace var namespace

    SettingsView(
        isPresented: $isPresented,
        profileNamespace: namespace
    )
    .environmentObject(LinkViewModel(accessTokenProvider: {
        return "mock-access-token"
    }))
    .environmentObject(ChatSessionsViewModel())
}
