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
            if navigationViewModel.isOpen {
                Color.clear
            } else {
                let viewId: String = {
                    if let sid = sessionsViewModel.activeSessionId { return "session_\(sid.uuidString)" }
                    return "new_\(sessionsViewModel.chatViewKey.uuidString)"
                }()
                ChatView(sessionId: sessionsViewModel.activeSessionId)
                    .id(viewId)
            }
        }
    }
}

#Preview {
    MainAppView()
        .environmentObject(SidebarNavigationViewModel())
        .environmentObject(ChatSessionsViewModel())
}
