import SwiftUI

struct ChatHeaderView: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel
    @EnvironmentObject private var sessionsViewModel: ChatSessionsViewModel

    var showDivider: Bool = true

    var body: some View {
        HStack {
            Button(action: {
                Haptics.impact(.medium)
                navigationViewModel.openSidebar()
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .frame(width: 44, height: 44)

                    let unreadCount = sessionsViewModel.unreadPartnerSessionIds.count + sessionsViewModel.pendingRequests.count
                    if unreadCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                            Text("\(min(unreadCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }
                        .frame(width: 16, height: 16)
                        .offset(x: -5, y: 5)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        Color.clear
                            .glassEffect(.regular)
                    } else {
                        Color(.systemGray6)
                            .opacity(0.8)
                    }
                }
            )
            .clipShape(Circle())
            .buttonStyle(.plain)
            .contentShape(Circle())
            .padding(.top, 2)

            Spacer()

            Button(action: {
                Haptics.impact(.light)
                sessionsViewModel.startNewChat()
            }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    .frame(width: 44, height: 44)
                    .offset(y: -1.5)
            }
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        Color.clear
                            .glassEffect(.regular)
                    } else {
                        Color(.systemGray6)
                            .opacity(0.8)
                    }
                }
            )
            .clipShape(Circle())
            .buttonStyle(.plain)
            .contentShape(Circle())
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
        .environmentObject(ChatSessionsViewModel())
        .padding()
}

