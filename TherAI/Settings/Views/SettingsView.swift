import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    let profileNamespace: Namespace.ID

    @StateObject private var viewModel = SettingsViewModel()
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
                            if let user = AuthService.shared.currentUser {
                                // User name
                                if let fullName = user.userMetadata["full_name"]?.stringValue, !fullName.isEmpty {
                                    Text(fullName)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                } else if let name = user.userMetadata["name"]?.stringValue, !name.isEmpty {
                                    Text(name)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                } else if let email = user.email {
                                    Text(email.components(separatedBy: "@").first ?? "User")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                
                                // Connection capsule (only show if connected)
                                if viewModel.isConnectedToPartner {
                                    ConnectionCapsuleView(
                                        partnerName: viewModel.partnerName,
                                        partnerAvatarURL: viewModel.partnerAvatarURL
                                    )
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                                }
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
            .sheet(item: $viewModel.destination) { dest in
                switch dest {
                case .link:
                    MainLinkView(accessTokenProvider: {
                        await AuthService.shared.getAccessToken() ?? ""
                    })
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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .animation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0), value: isPresented)
        .onAppear {
            showCards = false
            
            // Refresh connection status immediately
            viewModel.refreshConnectionStatus()
            
            // Preload avatar for personalization screen
            viewModel.preloadAvatar()
            
            // Load profile information
            viewModel.loadProfileInfo()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                    showCards = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .avatarChanged)) { _ in
            // Force refresh of the avatar display by changing the ID
            avatarRefreshKey = UUID()
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
