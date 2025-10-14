//
//  ContentView.swift
//  TherAI
//
//  Created by Stephan  on 29.08.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    @EnvironmentObject private var sessionsViewModel: ChatSessionsViewModel
    @State private var showSplash: Bool = false

    var body: some View {
        ZStack {
            Group {
                if authService.isAuthenticated {
                    SlideOutSidebarContainerView {
                        MainAppView()
                    }
                } else {
                    AuthView()
                }
            }
            // Splash overlay
            if showSplash {
                AppSplashOverlayView(isVisible: $showSplash)
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
        .task(id: authService.isAuthenticated) {
            guard authService.isAuthenticated else { return }
            // Show splash and run bootstrap
            showSplash = true
            // Ensure observers run
            sessionsViewModel.setNavigationViewModel(navigationViewModel)
            sessionsViewModel.startObserving()
            await sessionsViewModel.bootstrapInitialData()
            // Small delay for a pleasing fade-out
            try? await Task.sleep(nanoseconds: 250_000_000)
            showSplash = false
        }
    }
}

private struct AppSplashOverlayView: View {
    @Binding var isVisible: Bool

    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            Image(systemName: "infinity")
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.58, blue: 1.00),
                            Color(red: 0.63, green: 0.32, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        scale = 1.06
                    }
                }
        }
        .opacity(opacity)
        .onChange(of: isVisible) { _, visible in
            if visible {
                withAnimation(.easeInOut(duration: 0.2)) { opacity = 1.0 }
            } else {
                withAnimation(.easeInOut(duration: 0.35)) { opacity = 0.0 }
            }
        }
        .onAppear {
            opacity = isVisible ? 1.0 : 0.0
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ContentView()
}
