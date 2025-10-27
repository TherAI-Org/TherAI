import SwiftUI

struct SidebarAvatarView: View {
    let avatarURL: String?
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var refreshKey = UUID()
    
    private let avatarCacheManager = AvatarCacheManager.shared
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    )
            } else {
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
            }
        }
        .id(refreshKey)
        .onAppear {
            loadAvatar()
        }
        .onChange(of: avatarURL) { _, newURL in
            // Force refresh when avatar URL changes
            refreshKey = UUID()
            loadAvatar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .avatarChanged)) { _ in
            // Force refresh when avatar changes notification is received
            refreshKey = UUID()
            loadAvatar()
        }
    }
    
    private func loadAvatar() {
        guard let urlString = avatarURL, !urlString.isEmpty else {
            image = nil
            isLoading = false
            return
        }
        
        // First try to get cached image immediately
        if let cachedImage = avatarCacheManager.getImageIfCached(urlString: urlString) {
            image = cachedImage
            isLoading = false
            return
        }
        
        // If not cached, show loading and fetch
        isLoading = true
        image = nil
        
        Task {
            let fetchedImage = await avatarCacheManager.getCachedImage(urlString: urlString)
            await MainActor.run {
                image = fetchedImage
                isLoading = false
            }
        }
    }
}

#Preview {
    SidebarAvatarView(avatarURL: nil)
        .frame(width: 36, height: 36)
}
