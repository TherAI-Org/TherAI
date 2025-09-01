import SwiftUI

struct CustomNavigationBar: View {
    let title: String
    let showSettingsButton: Bool
    let settingsAction: (() -> Void)?
    
    init(
        title: String,
        showSettingsButton: Bool = false,
        settingsAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.showSettingsButton = showSettingsButton
        self.settingsAction = settingsAction
    }
    
    var body: some View {
        HStack {
            HamburgerMenuButton()
            
            Spacer()
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            if showSettingsButton {
                Button(action: {
                    settingsAction?()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
            } else {
                // Empty view to balance the layout
                Color.clear
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

#Preview {
    VStack {
        CustomNavigationBar(title: "Chat", showSettingsButton: true) {
            print("Settings tapped")
        }
        CustomNavigationBar(title: "Profile")
        Spacer()
    }
    .environmentObject(SlideOutSidebarViewModel())
}
