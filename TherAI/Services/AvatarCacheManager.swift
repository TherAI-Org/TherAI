import Foundation
import SwiftUI
import UIKit

@MainActor
class AvatarCacheManager: ObservableObject {
    nonisolated static let shared = AvatarCacheManager()
    
    // Memory cache for immediate access
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // URLSession with disk cache
    nonisolated private let urlSession: URLSession
    
    // Track loading states
    @Published var loadingAvatars: Set<String> = []
    @Published var cachedAvatars: [String: UIImage] = [:]
    
    // Notification observer
    private var avatarChangeObserver: NSObjectProtocol?
    
    nonisolated private init() {
        // Configure URLSession with disk cache
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB memory cache
            diskCapacity: 200 * 1024 * 1024,  // 200MB disk cache
            diskPath: "avatar_cache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        self.urlSession = URLSession(configuration: config)
        
        // Configure memory cache
        Task { @MainActor in
            memoryCache.countLimit = 100
            memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        }
        
        // Set up notification observer for avatar changes
        Task { @MainActor in
            setupAvatarChangeObserver()
        }
    }
    
    deinit {
        if let observer = avatarChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupAvatarChangeObserver() {
        avatarChangeObserver = NotificationCenter.default.addObserver(
            forName: .avatarChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAvatarChange()
            }
        }
    }
    
    private func handleAvatarChange() async {
        // Clear all caches to force reload of all avatars
        clearCache()
        
        // Force UI update
        objectWillChange.send()
    }
    
    // MARK: - Public Methods
    
    /// Preload and cache avatar images from URLs
    func preloadAvatars(urls: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for urlString in urls {
                guard !urlString.isEmpty else { continue }
                group.addTask {
                    _ = await self.loadAndCacheImage(urlString: urlString)
                }
            }
        }
    }
    
    /// Get cached image for URL, or load if not cached
    func getCachedImage(urlString: String) async -> UIImage? {
        // Check memory cache first
        if let cachedImage = memoryCache.object(forKey: urlString as NSString) {
            return cachedImage
        }
        
        // Check if we have it in our published cache
        if let cachedImage = cachedAvatars[urlString] {
            memoryCache.setObject(cachedImage, forKey: urlString as NSString)
            return cachedImage
        }
        
        // Load from network/disk cache
        return await loadAndCacheImage(urlString: urlString)
    }
    
    /// Check if image is already cached
    func isImageCached(urlString: String) -> Bool {
        return cachedAvatars[urlString] != nil
    }
    
    /// Clear all caches
    func clearCache() {
        Task { @MainActor in
            memoryCache.removeAllObjects()
            cachedAvatars.removeAll()
        }
        urlSession.configuration.urlCache?.removeAllCachedResponses()
    }
    
    /// Force refresh all avatar displays
    func forceRefreshAllAvatars() async {
        // Clear all caches
        clearCache()
        
        // Force UI update
        await MainActor.run {
            objectWillChange.send()
        }
    }
    
    /// Clear a specific image from cache
    func clearSpecificImage(urlString: String) async {
        await MainActor.run {
            // Remove from memory cache
            memoryCache.removeObject(forKey: urlString as NSString)
            
            // Remove from published cache
            _ = cachedAvatars.removeValue(forKey: urlString)
        }
        
        // Remove from disk cache
        if let url = URL(string: urlString) {
            urlSession.configuration.urlCache?.removeCachedResponse(for: URLRequest(url: url))
        }
    }
    
    /// Cache an image immediately for instant display
    func cacheImageImmediately(urlString: String, image: UIImage) async {
        await MainActor.run {
            // Cache in memory
            memoryCache.setObject(image, forKey: urlString as NSString)
            
            // Update published cache
            cachedAvatars[urlString] = image
        }
    }
    
    // MARK: - Private Methods
    
    private func loadAndCacheImage(urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        
        // Mark as loading
        loadingAvatars.insert(urlString)
        defer { loadingAvatars.remove(urlString) }
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }
            
            // Cache in memory
            memoryCache.setObject(image, forKey: urlString as NSString)
            
            // Update published cache
            cachedAvatars[urlString] = image
            
            return image
            
        } catch {
            print("Failed to load avatar image from \(urlString): \(error)")
            return nil
        }
    }
}

// MARK: - SwiftUI Integration

extension AvatarCacheManager {
    /// Create an AsyncImage that uses the cache manager
    func cachedAsyncImage(urlString: String?, 
                         placeholder: @escaping () -> AnyView = { AnyView(ProgressView()) },
                         fallback: @escaping () -> AnyView = { AnyView(EmptyView()) }) -> some View {
        Group {
            if let urlString = urlString, !urlString.isEmpty {
                CachedAsyncImageView(
                    urlString: urlString,
                    cacheManager: self,
                    placeholder: placeholder,
                    fallback: fallback
                )
            } else {
                fallback()
            }
        }
    }
}

struct CachedAsyncImageView: View {
    let urlString: String
    let cacheManager: AvatarCacheManager
    let placeholder: () -> AnyView
    let fallback: () -> AnyView
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                placeholder()
            } else {
                fallback()
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }
        
        image = await cacheManager.getCachedImage(urlString: urlString)
    }
}
