import SwiftUI
import PhotosUI
import UIKit

struct SlideOutSidebarContainerView<Content: View>: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    @EnvironmentObject private var sessionsViewModel: ChatSessionsViewModel

    @Namespace private var profileNamespace

    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var linkVM: LinkViewModel

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var linkedMonthYear: String? {
        switch linkVM.state {
        case .linked:
            if let date = linkVM.linkedAt {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: date)
            }
            return nil
        default:
            return nil
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let blurIntensity: CGFloat = {
                let widthD = Double(width)
                if navigationViewModel.isOpen {
                    let dragProgress = abs(Double(navigationViewModel.dragOffset)) / max(widthD, 1.0)
                    let value = max(0.0, 10.0 - (dragProgress * 20.0))
                    return CGFloat(value)
                } else {
                    let dragProgress = Double(navigationViewModel.dragOffset) / max(widthD, 1.0)
                    let value = min(abs(dragProgress) * 20.0, 10.0)
                    return CGFloat(value)
                }
            }()

            ZStack {
                // Main Content - slides completely off screen when sidebar is open
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: navigationViewModel.isOpen ? width + navigationViewModel.dragOffset : max(0, navigationViewModel.dragOffset))
                    .blur(radius: min(blurIntensity, 6))
                    // Faster response when toggling open/close, and tighter interactive spring while dragging
                    .animation(.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0), value: navigationViewModel.isOpen)
                    .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88, blendDuration: 0), value: navigationViewModel.dragOffset)

                // Slide-out Sidebar - slides in from left to fully replace main content
                // Compute sidebar offset once so we can position the edge blur exactly at the visible edge
                let sidebarOffsetX: CGFloat = navigationViewModel.isOpen ? navigationViewModel.dragOffset : (-width + max(0, navigationViewModel.dragOffset))

                SlidebarView(
                    isOpen: $navigationViewModel.isOpen,
                    profileNamespace: profileNamespace
                )
                .offset(x: sidebarOffsetX)
                .blur(radius: navigationViewModel.showSettingsOverlay ? 8 : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0), value: navigationViewModel.isOpen)
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88, blendDuration: 0), value: navigationViewModel.dragOffset)

                if navigationViewModel.showSettingsOverlay {
                    SettingsView(
                        profileNamespace: profileNamespace,
                        isPresented: $navigationViewModel.showSettingsOverlay
                    )
                    .environmentObject(sessionsViewModel)
                    .zIndex(2)
                    .animation(.spring(response: 0.42, dampingFraction: 0.92, blendDuration: 0), value: navigationViewModel.showSettingsOverlay)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !navigationViewModel.showSettingsOverlay else { return }
                        // Clamp to reduce layout thrash on rapid drags
                        let clamped = max(min(value.translation.width, width), -width)
                        navigationViewModel.handleDragGesture(clamped, width: width)
                    }
                    .onEnded { value in
                        guard !navigationViewModel.showSettingsOverlay else { return }
                        navigationViewModel.handleSwipeGesture(value.translation.width, velocity: value.velocity.width, width: width)
                    }
            )
        }
        .onAppear {
            sessionsViewModel.setNavigationViewModel(navigationViewModel)
            sessionsViewModel.setLinkViewModel(linkVM)
            sessionsViewModel.startObserving()
            navigationViewModel.dragOffset = 0
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .inactive, .background:
                withAnimation(nil) { navigationViewModel.dragOffset = 0 }
            case .active:
                withAnimation(nil) { navigationViewModel.dragOffset = 0 }
                Task { await sessionsViewModel.refreshSessions() }
            @unknown default:
                withAnimation(nil) { navigationViewModel.dragOffset = 0 }
            }
        }
        // If the sidebar is open, ensure the chat input isn't focused to prevent the keyboard from appearing underneath
        .onChange(of: navigationViewModel.isOpen) { open in
            if open {
                // Broadcast a notification to clear any chat input focus if needed
                NotificationCenter.default.post(name: .init("TherAI_ClearChatInputFocus"), object: nil)
            }
        }
    }
}

#Preview {
    SlideOutSidebarContainerView {
        Text("Main Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.1))
    }
    .environmentObject(LinkViewModel(accessTokenProvider: {
        return "mock-access-token"
    }))
}