import SwiftUI

struct ChatHeaderView: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel

    @Binding var selectedMode: ChatMode

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

            HStack {
                Spacer()

                ZStack {
                    Group {
                        if #available(iOS 26.0, *) {
                            Color.clear
                                .glassEffect()
                                .cornerRadius(28)
                                .frame(width: 200, height: 48)
                        } else {
                            Color.clear
                                .frame(width: 200, height: 48)
                        }
                    }

                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .frame(width: 90, height: 36)
                        .offset(x: selectedMode == .personal ? -48 : 48)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedMode)

                    HStack(spacing: 8) {
                        ForEach(ChatMode.allCases, id: \.self) { mode in
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()

                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedMode = mode
                                }
                            }) {
                                Text(mode.rawValue)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(selectedMode == mode ? .white : .primary)
                                    .frame(width: 90, height: 36)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                Spacer()
            }
            .frame(maxWidth: 200)
            .padding(.top, 10)
            Spacer()

            Color.clear
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .background(Color(.systemBackground))
    }
}


