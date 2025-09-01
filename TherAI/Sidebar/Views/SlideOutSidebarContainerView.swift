import SwiftUI

struct SlideOutSidebarContainerView<Content: View>: View {
    @StateObject private var viewModel = SlideOutSidebarViewModel()
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    // Calculate blur intensity based on drag progress - now works bidirectionally
    private var blurIntensity: Double {
        let screenWidth = UIScreen.main.bounds.width
        
        if viewModel.isOpen {
            // When sidebar is open, blur decreases as we drag left (negative dragOffset)
            let dragProgress = abs(viewModel.dragOffset) / screenWidth
            return max(0, 10 - (dragProgress * 20)) // Start at 10 blur, decrease to 0
        } else {
            // When sidebar is closed, blur increases as we drag right (positive dragOffset)
            let dragProgress = viewModel.dragOffset / screenWidth
            return min(dragProgress * 20, 10) // Start at 0 blur, increase to 10
        }
    }
    
    var body: some View {
        ZStack {
            // Main Content - slides completely off screen when sidebar is open
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: viewModel.isOpen ? UIScreen.main.bounds.width + viewModel.dragOffset : viewModel.dragOffset)
                .blur(radius: blurIntensity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: viewModel.isOpen)
                .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: viewModel.dragOffset)
            
            // Slide-out Sidebar - slides in from left to fully replace main content
            SlideOutSidebarView(
                selectedTab: $viewModel.selectedTab,
                isOpen: $viewModel.isOpen
            )
            .offset(x: viewModel.isOpen ? viewModel.dragOffset : -UIScreen.main.bounds.width + viewModel.dragOffset)
            .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: viewModel.isOpen)
            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: viewModel.dragOffset)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Always allow dragging - let the view model handle the constraints
                    viewModel.handleDragGesture(value.translation.width)
                }
                .onEnded { value in
                    // Always handle swipe gestures - let the view model decide what to do
                    viewModel.handleSwipeGesture(value.translation.width, velocity: value.velocity.width)
                }
        )
        .environmentObject(viewModel)
    }
}

#Preview {
    SlideOutSidebarContainerView {
        Text("Main Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.1))
    }
}
