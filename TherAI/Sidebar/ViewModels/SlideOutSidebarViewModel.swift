import SwiftUI

class SlideOutSidebarViewModel: ObservableObject {
    @Published var isOpen = false
    @Published var selectedTab: SlideOutSidebarView.Tab = .chat
    @Published var dragOffset: CGFloat = 0
    
    private let screenWidth = UIScreen.main.bounds.width
    
    func openSidebar() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            isOpen = true
            dragOffset = 0
        }
    }
    
    func closeSidebar() {
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
    
    func selectTab(_ tab: SlideOutSidebarView.Tab) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            selectedTab = tab
            isOpen = false
            dragOffset = 0
        }
    }
    
    func handleDragGesture(_ translation: CGFloat) {
        if isOpen {
            // When sidebar is open, dragging left (negative) should close, dragging right (positive) should stay open
            // Map the translation directly - negative values close the sidebar, positive values keep it open
            let newOffset = max(-screenWidth, min(0, translation))
            dragOffset = newOffset
        } else {
            // When sidebar is closed, dragging right (positive) should open, dragging left (negative) should stay closed
            // Only allow positive translation to open the sidebar
            let newOffset = max(0, min(screenWidth, translation))
            dragOffset = newOffset
        }
    }
    
    func handleSwipeGesture(_ translation: CGFloat, velocity: CGFloat) {
        let threshold: CGFloat = screenWidth * 0.3 // 30% of screen width
        let velocityThreshold: CGFloat = 500
        
        if isOpen {
            // Sidebar is open - check if should close (swipe left = negative translation)
            if translation < -threshold || velocity < -velocityThreshold {
                closeSidebar()
            } else {
                // Snap back to open
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    dragOffset = 0
                }
            }
        } else {
            // Sidebar is closed - check if should open (swipe right = positive translation)
            if translation > threshold || velocity > velocityThreshold {
                openSidebar()
            } else {
                // Snap back to closed
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    dragOffset = 0
                }
            }
        }
    }
}
