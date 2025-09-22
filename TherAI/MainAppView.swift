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
                    .id(sessionsViewModel.chatViewKey)
            case .profile:
                ProfileView()
            }
        }
    }
}

#Preview {
    MainAppView()
        .environmentObject(SidebarNavigationViewModel())
        .environmentObject(ChatSessionsViewModel())
}
