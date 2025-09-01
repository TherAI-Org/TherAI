import SwiftUI

struct HamburgerMenuButton: View {
    @EnvironmentObject private var sidebarViewModel: SlideOutSidebarViewModel
    
    var body: some View {
        Button(action: {
            sidebarViewModel.openSidebar()
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    HamburgerMenuButton()
        .environmentObject(SlideOutSidebarViewModel())
}
