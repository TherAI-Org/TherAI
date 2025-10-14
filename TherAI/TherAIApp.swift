//
//  TherAIApp.swift
//  TherAI
//
//  Created by Stephan  on 29.08.2025.
//

import SwiftUI
import UIKit
import Supabase
import BackgroundTasks

@main
struct TherAIApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var auth = AuthService.shared
    @StateObject private var linkVM = LinkViewModel(accessTokenProvider: {
        let session = try await AuthService.shared.client.auth.session
        return session.accessToken
    })
    @StateObject private var navigationViewModel = SidebarNavigationViewModel()
    @StateObject private var sessionsViewModel = ChatSessionsViewModel()

    @AppStorage(PreferenceKeys.appearancePreference) private var appearance: String = "System"
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register BGTask handlers before app finishes launching
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(linkVM)
                .environmentObject(navigationViewModel)
                .environmentObject(sessionsViewModel)
                .preferredColorScheme(
                    appearance == "Light" ? .light : appearance == "Dark" ? .dark : nil
                )
                .onOpenURL { url in
                    AuthService.shared.client.auth.handle(url)
                    let base = AuthService.getInfoPlistValue(for: "SHARE_LINK_BASE_URL") as? String
                    let configuredHost = base.flatMap { URL(string: $0)?.host }
                    if url.host == configuredHost || url.path.hasPrefix("/link") {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let token = components.queryItems?.first(where: { $0.name == "code" })?.value,
                           !token.isEmpty {
                            if auth.isAuthenticated {
                                Task { await linkVM.acceptInvite(using: token) }
                            } else {
                                linkVM.captureIncomingInviteToken(token)
                            }
                        }
                    }
                }
                .onChange(of: auth.isAuthenticated) { _, isAuthed in
                    if !isAuthed {
                        // User logged out - reset session view model for fresh login
                        sessionsViewModel.resetForLogout()
                    }
                    if isAuthed, let token = linkVM.pendingInviteToken, !token.isEmpty {  // If user just signed in and we have a pending invite token, accept it
                        Task {
                            await linkVM.acceptInvite(using: token)
                            linkVM.pendingInviteToken = nil
                        }
                    }
                    if isAuthed {
                        Task {
                            await linkVM.ensureInviteReady()
                            sessionsViewModel.startObserving()
                            // Trigger bootstrap early when auth flips to true
                            await sessionsViewModel.bootstrapInitialData()
                            PushNotificationManager.shared.tryUploadIfAuthenticated()
                            PushNotificationManager.shared.consumePendingIfReady()
                        }
                    }
                }
                .task {
                    if auth.isAuthenticated {
                        await linkVM.ensureInviteReady()
                        sessionsViewModel.startObserving()
                    }
                    PushNotificationManager.shared.requestAuthorizationAndRegister()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        DispatchQueue.main.async {
                            PushNotificationManager.shared.consumePendingIfReady()
                        }
                    }
                }
        }
    }
}
