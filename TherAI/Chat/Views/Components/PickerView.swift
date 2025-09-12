import SwiftUI
import UIKit

struct PickerView: View {

    @Binding var selectedMode: ChatMode

    enum ChatMode: String, CaseIterable {
        case personal = "Personal"
        case dialogue = "Dialogue"
    }

    var body: some View {
        HStack {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(.systemGray6))
                    .frame(width: 200, height: 48)

                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                    .frame(width: 90, height: 36)
                    .offset(x: selectedMode == .personal ? -48 : 48)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedMode)

                HStack(spacing: 8) {
                    ForEach(ChatMode.allCases, id: \.self) { mode in
                        Button(action: {
                            // Add haptic feedback
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
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
}

#Preview {
    PickerView(selectedMode: .constant(.personal))
}
