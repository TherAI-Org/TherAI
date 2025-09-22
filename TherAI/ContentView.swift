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
                    MainAppView()
                }
            } else {
                AuthView()
            }
        }
    }
}

#Preview {
    ContentView()
}
