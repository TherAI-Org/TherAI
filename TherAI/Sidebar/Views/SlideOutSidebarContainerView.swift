import SwiftUI

struct SlideOutSidebarContainerView<Content: View>: View {

    @StateObject private var viewModel = SlideOutSidebarViewModel()
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let blurIntensity: CGFloat = {
                let widthD = Double(width)
                if viewModel.isOpen {
                    let dragProgress = abs(Double(viewModel.dragOffset)) / max(widthD, 1.0)
                    let value = max(0.0, 10.0 - (dragProgress * 20.0))
                    return CGFloat(value)
                } else {
                    let dragProgress = Double(viewModel.dragOffset) / max(widthD, 1.0)
                    let value = min(dragProgress * 20.0, 10.0)
                    return CGFloat(value)
                }
            }()
            ZStack {
                // Main Content - slides completely off screen when sidebar is open
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: viewModel.isOpen ? width + viewModel.dragOffset : viewModel.dragOffset)
                    .blur(radius: blurIntensity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: viewModel.isOpen)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: viewModel.dragOffset)

                // Slide-out Sidebar - slides in from left to fully replace main content
                SlideOutSidebarView(
                    selectedTab: $viewModel.selectedTab,
                    isOpen: $viewModel.isOpen
                )
                .offset(x: viewModel.isOpen ? viewModel.dragOffset : -width + viewModel.dragOffset)
                .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0), value: viewModel.isOpen)
                .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: viewModel.dragOffset)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.handleDragGesture(value.translation.width, width: width)
                    }
                    .onEnded { value in
                        viewModel.handleSwipeGesture(value.translation.width, velocity: value.velocity.width, width: width)
                    }
            )
        }
        .environmentObject(viewModel)
        .onAppear { viewModel.startObserving() }
        .sheet(isPresented: $viewModel.showProfileSheet) {
            ProfileView()
        }
    }
}

#Preview {
    SlideOutSidebarContainerView {
        Text("Main Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.1))
    }
    .environmentObject(SlideOutSidebarViewModel())
}
