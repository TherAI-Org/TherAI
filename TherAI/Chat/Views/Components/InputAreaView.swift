import SwiftUI
import UIKit

struct InputAreaView: View {

    @Binding var inputText: String
    @Binding var isLoading: Bool

    let isInputFocused: FocusState<Bool>.Binding
    let send: () -> Void
    let stop: () -> Void
    let onCreatedNewSession: (UUID) -> Void

    var body: some View {

        let isSendDisabled = !isLoading && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let cornerRadius: CGFloat = 24
        let sendSize: CGFloat = 28

        HStack(spacing: 12) {
            TextField("Share what's on your mind", text: $inputText)
                .font(Typography.body)
                .foregroundColor(.primary)
                .onSubmit { 
                    guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    send() 
                }
                .focused(isInputFocused)
            
            Button(action: { 
                // Add haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                if isLoading {
                    stop()
                } else {
                    send()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isSendDisabled ? 
                              Color(uiColor: .systemGray5) : 
                              Color(red: 0.4, green: 0.2, blue: 0.6))
                        .frame(width: sendSize, height: sendSize)

                    Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSendDisabled ? .secondary : .white)
                }
            }
            .disabled(isSendDisabled)
            .scaleEffect(isSendDisabled ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSendDisabled)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            isInputFocused.wrappedValue ? 
                            Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.8) : 
                            Color.clear, 
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.04), 
                    radius: 8, 
                    x: 0, 
                    y: 2
                )
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .animation(.easeInOut(duration: 0.2), value: isInputFocused.wrappedValue)
    }
}

#Preview {
    @FocusState var isFocused: Bool
    return InputAreaView(
        inputText: .constant(""),
        isLoading: .constant(false),
        isInputFocused: $isFocused,
        send: {},
        stop: {},
        onCreatedNewSession: { _ in }
    )
}


