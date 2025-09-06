//
//  ContentView.swift
//  TherAI
//
//  Created by Stephan  on 29.08.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared

    var body: some View {
        Group {
            if authService.isAuthenticated {
                SlideOutSidebarContainerView {
                    MainContentView()
                }
            } else {
                AuthView()
            }
        }
    }
}

// MARK: - Main Content View
struct MainContentView: View {
    @EnvironmentObject private var sidebarViewModel: SlideOutSidebarViewModel
    
    var body: some View {
        Group {
            switch sidebarViewModel.selectedTab {
            case .chat:
                ChatView(sessionId: sidebarViewModel.activeSessionId)
                    .id(sidebarViewModel.chatViewKey)
            case .profile:
                ProfileView()
            }
        }
    }
}

#Preview {
    ContentView()
}
