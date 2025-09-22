import SwiftUI
import UIKit

enum SidebarTab: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case profile = "Profile"

    var id: String { self.rawValue }
}

class SidebarNavigationViewModel: ObservableObject {

    @Published var isOpen = false
    @Published var isDialogueOpen = false
    @Published var selectedTab: SidebarTab = .chat
    @Published var dragOffset: CGFloat = 0

    @Published var showProfileSheet: Bool = false
    @Published var showProfileOverlay: Bool = false
    @Published var showSettingsOverlay: Bool = false
    @Published var showSettingsSheet: Bool = false
    @Published var showLinkSheet: Bool = false

    @Published var isNotificationsExpanded: Bool = false
    @Published var isChatsExpanded: Bool = false

    func openSidebar() {
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isDialogueOpen = false
            isOpen = true
            dragOffset = 0
        }
    }

    func closeSidebar() {
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isOpen = false
            dragOffset = 0
        }
    }

    func toggleSidebar() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isOpen.toggle()
            dragOffset = 0
        }
    }

    func selectTab(_ tab: SidebarTab) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            selectedTab = tab
            isOpen = false
            dragOffset = 0
        }
    }

    func openDialogue() {
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isOpen = false
            isDialogueOpen = true
            dragOffset = 0
        }
    }

    func closeDialogue() {
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isDialogueOpen = false
            dragOffset = 0
        }
    }

    func handleDragGesture(_ translation: CGFloat, width: CGFloat) {
        if isOpen {
            let newOffset = max(-width, min(0, translation))
            dragOffset = newOffset
        } else {
            dragOffset = 0
        }
    }

    func handleSwipeGesture(_ translation: CGFloat, velocity: CGFloat, width: CGFloat) {
        let threshold: CGFloat = width * 0.3
        let velocityThreshold: CGFloat = 500

        if isOpen {
            if translation < -threshold || velocity < -velocityThreshold {
                closeSidebar()
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    dragOffset = 0
                }
            }
        } else if isDialogueOpen {
            if translation > threshold || velocity > velocityThreshold {
                closeDialogue()
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    dragOffset = 0
                }
            }
        } else {
            if translation > threshold || velocity > velocityThreshold {
                openSidebar()
            } else if translation < -threshold || velocity < -velocityThreshold {
                openDialogue()
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    dragOffset = 0
                }
            }
        }
    }
}
