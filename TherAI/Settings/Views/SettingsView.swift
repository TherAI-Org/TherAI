import SwiftUI
import PhotosUI

struct SettingsView: View {

    let profileNamespace: Namespace.ID

    @EnvironmentObject private var linkVM: LinkViewModel
    @EnvironmentObject private var sessionsVM: ChatSessionsViewModel

    @StateObject private var viewModel = SettingsViewModel()

    @Binding var isPresented: Bool

    @State private var showCards = false
    @State private var avatarRefreshKey = UUID()

    // Break up complex view builders to help the type-checker
    private var avatarPlaceholder: AnyView { AnyView(Color.clear) }

    private var avatarFallback: AnyView {
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
                    Circle().stroke(Color.white.opacity(0.9), lineWidth: 2)
                )
                .overlay(
                    Image(systemName: "gearshape")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                )
        )
    }

    private var avatarView: some View {
        ZStack {
            AvatarCacheManager.shared.cachedAsyncImage(
                urlString: sessionsVM.myAvatarURL,
                placeholder: { avatarPlaceholder },
                fallback: { avatarFallback }
            )
            .frame(width: 84, height: 84)
            .clipShape(Circle())
            .matchedGeometryEffect(id: sessionsVM.myAvatarURL != nil ? "settingsGearIcon" : "settingsEmblem", in: profileNamespace)
            .id(avatarRefreshKey)
        }
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .padding(.bottom, 12)
    }

    private var headerInfoView: some View {
        VStack(spacing: 6) {
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

            if let email = AuthService.shared.currentUser?.email, !email.isEmpty {
                Text(email)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(.label).opacity(0.5))
            }
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var sectionsListView: some View {
        VStack(spacing: 24) {
            ForEach(Array(viewModel.settingsSections.enumerated()), id: \.offset) { sectionIndex, section in

                SettingsCardView(
                    section: section,
                    onToggle: { settingIndex in
                        viewModel.toggleSetting(for: sectionIndex, settingIndex: settingIndex)
                    },
                    onAction: { settingIndex in
                        let selected = viewModel.settingsSections[sectionIndex].settings[settingIndex]
                        if section.title == "Account" && selected.title == "Unlink Partner" {
                            Task { await linkVM.unlink() }
                        } else {
                            viewModel.handleSettingAction(for: sectionIndex, settingIndex: settingIndex)
                        }
                    },
                    onPickerSelect: { settingIndex, value in
                        viewModel.handlePickerSelection(for: sectionIndex, settingIndex: settingIndex, value: value)
                    }
                )
            }

            VStack(spacing: 0) {
                Text("VERSION 1.0.0")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.top, 20)
            }
        }
    }

    // Removed header accessory for Link Your Partner as per new design

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 0) {
                        avatarView
                        headerInfoView

                        if showCards {
                            sectionsListView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
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
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                                .offset(y: 2)
                                .padding(.leading, -6)
                        }
                        .buttonStyle(.plain)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            Haptics.impact(.light)
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                                .offset(y: 2)
                                .padding(.trailing, -6)
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
        profileNamespace: namespace,
        isPresented: $isPresented
    )
    .environmentObject(LinkViewModel(accessTokenProvider: {
        return "mock-access-token"
    }))
    .environmentObject(ChatSessionsViewModel())
}
