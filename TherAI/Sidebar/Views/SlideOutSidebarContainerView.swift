import SwiftUI

struct SlideOutSidebarContainerView<Content: View>: View {
    @StateObject private var viewModel = SlideOutSidebarViewModel()
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    // Calculate blur intensity based on drag progress
    private var blurIntensity: Double {
        let screenWidth = UIScreen.main.bounds.width
        let dragProgress = abs(viewModel.dragOffset) / screenWidth
        return min(dragProgress * 20, 10) // Max blur of 10, scales with drag progress
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
                    viewModel.handleDragGesture(value.translation.width)
                }
                .onEnded { value in
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
