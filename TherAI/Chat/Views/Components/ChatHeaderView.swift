import SwiftUI

struct ChatHeaderView: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel

    @Binding var selectedMode: PickerView.ChatMode

    var body: some View {
        HStack {
            Button(action: {
                Haptics.impact(.medium)
                navigationViewModel.openSidebar()
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            }

            Spacer()

            PickerView(selectedMode: $selectedMode)
                .frame(maxWidth: 200)
                .padding(.top, 10)
            Spacer()

            // Invisible spacer to balance the hamburger button
            Color.clear
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .background(Color(.systemBackground))
    }
}


