import SwiftUI

struct ChatHeaderView: View {

    @EnvironmentObject private var navigationViewModel: SidebarNavigationViewModel

    @Binding var selectedMode: ChatMode
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

            HStack {
                Spacer()

                ZStack {
                    HStack(spacing: 8) {
                        ForEach(ChatMode.allCases, id: \.self) { mode in
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()

                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedMode = mode
                                }
                            }) {
                                Text(mode.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedMode == mode ? .primary : .secondary)
                                    .frame(width: 90, height: 36)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .anchorPreference(key: TabBoundsKey.self, value: .bounds) { anchor in
                                [mode: anchor]
                            }
                        }
                    }
                    .overlayPreferenceValue(TabBoundsKey.self) { prefs in
                        GeometryReader { proxy in
                            if let anchor = prefs[selectedMode] {
                                let rect = proxy[anchor]
                                Rectangle()
                                    .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    .frame(width: 28, height: 3)
                                    .cornerRadius(1.5)
                                    .position(x: rect.midX, y: rect.maxY + 1)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedMode)
                            }
                        }
                    }
                }

                Spacer()
            }
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

private struct TabBoundsKey: PreferenceKey {
    static var defaultValue: [ChatMode: Anchor<CGRect>] = [:]
    static func reduce(value: inout [ChatMode: Anchor<CGRect>], nextValue: () -> [ChatMode: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}


private struct ChatHeaderPreviewHost: View {
    @State private var selectedMode: ChatMode

    init(_ mode: ChatMode) {
        _selectedMode = State(initialValue: mode)
    }

    var body: some View {
        ChatHeaderView(selectedMode: $selectedMode)
            .environmentObject(SidebarNavigationViewModel())
    }
}

#Preview("Personal", traits: .sizeThatFitsLayout) {
    ChatHeaderPreviewHost(.personal)
        .padding()
}
