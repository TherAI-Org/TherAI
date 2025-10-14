import SwiftUI

struct ProfileSectionView: View {
    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    @EnvironmentObject private var sessionsViewModel: ChatSessionsViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSettingsSheet = false
    @State private var avatarRefreshKey = UUID()
    @Namespace private var profileNamespace

    private var userName: String {
        // Prefer loaded profile info full name if available via SettingsViewModel cache on NotificationCenter
        if let cached = UserDefaults.standard.string(forKey: "therai_profile_full_name"), !cached.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cached
        }
        if let user = AuthService.shared.currentUser {
            let metadata = user.userMetadata
            if let fullName = metadata["full_name"]?.stringValue, !fullName.isEmpty {
                return fullName
            } else if let name = metadata["name"]?.stringValue, !name.isEmpty {
                return name
            } else if let displayName = metadata["display_name"]?.stringValue, !displayName.isEmpty {
                return displayName
            }
            return user.email ?? "User"
        }
        return "User"
    }

    var body: some View {
        Button(action: {
            Haptics.impact(.medium)
            showSettingsSheet = true
        }) {
            HStack(spacing: 8) {
                // Profile Picture
                AvatarCacheManager.shared.cachedAsyncImage(
                    urlString: sessionsViewModel.myAvatarURL,
                    placeholder: {
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
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                )
                        )
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
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                )
                        )
                    }
                )
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .id(avatarRefreshKey)

                // User Name
                Text(userName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(1)

                Spacer(minLength: 20)

                // Settings Icon with gradient
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.26, green: 0.58, blue: 1.00),
                                Color(red: 0.63, green: 0.32, blue: 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(
                isPresented: $showSettingsSheet,
                profileNamespace: profileNamespace
            )
            .environmentObject(sessionsViewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileChanged)) { _ in
            // Update cached name and refresh UI
            if let cached = UserDefaults.standard.string(forKey: "therai_profile_full_name"), !cached.isEmpty {
                // trigger view refresh
                avatarRefreshKey = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .avatarChanged)) { _ in
            // Force refresh of the avatar display by changing the ID
            avatarRefreshKey = UUID()
        }
    }
}

#Preview {
    ProfileSectionView()
        .environmentObject(SidebarNavigationViewModel())
        .environmentObject(ChatSessionsViewModel())
        .background(Color.gray.opacity(0.1))
        .padding()
}
