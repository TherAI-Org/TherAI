import SwiftUI

struct ChatHeaderView: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    var showDivider: Bool = true

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
            .padding(.top, 2)

            Spacer()
            Spacer()

            Color.clear
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            if showDivider {
                Rectangle()
                    .fill(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.16))
                    .frame(height: 1)
            }
        }
    }
}

#Preview("Header", traits: .sizeThatFitsLayout) {
    ChatHeaderView()
        .environmentObject(SidebarNavigationViewModel())
        .padding()
}
