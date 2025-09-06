//
//  TherAIApp.swift
//  TherAI
//
//  Created by Stephan  on 29.08.2025.
//

import SwiftUI
import Supabase

@main
struct TherAIApp: App {
    @StateObject private var auth = AuthService.shared
    @StateObject private var linkVM = LinkViewModel(accessTokenProvider: {
        // Obtain current access token from Supabase
        let session = try await AuthService.shared.client.auth.session
        return session.accessToken
    })
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle OAuth authentication callbacks
                    AuthService.shared.client.auth.handle(url)
                    // Handle universal links for partner invites
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
                    // If user just signed in and we have a pending invite token, accept it
                    if isAuthed, let token = linkVM.pendingInviteToken, !token.isEmpty {
                        Task {
                            await linkVM.acceptInvite(using: token)
                            linkVM.pendingInviteToken = nil
                        }
                    }
                }
        }
    }
}
