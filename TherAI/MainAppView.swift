//
//  MainAppView.swift
//  TherAI
//
//  Created by Stephan  on 29.08.2025.
//

import SwiftUI

struct MainAppView: View {
    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    @EnvironmentObject private var sessionsViewModel: ChatSessionsViewModel

    var body: some View {
        Group {
            switch navigationViewModel.selectedTab {
            case .chat:
                ChatView(sessionId: sessionsViewModel.activeSessionId)
            case .profile:
                // Profile is shown as an overlay via navigationViewModel.showProfileOverlay
                // Render ChatView here to avoid presenting a separate Profile screen
                ChatView(sessionId: sessionsViewModel.activeSessionId)
            }
        }
    }
}

#Preview {
    MainAppView()
        .environmentObject(SidebarNavigationViewModel())
        .environmentObject(ChatSessionsViewModel())
}
