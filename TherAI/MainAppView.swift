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
        ChatView(sessionId: sessionsViewModel.activeSessionId)
    }
}

#Preview {
    MainAppView()
        .environmentObject(SidebarNavigationViewModel())
        .environmentObject(ChatSessionsViewModel())
}
