import SwiftUI

struct PersonalEmptyStateView: View {

    @State private var isVisible: Bool = false

    let prompt: String

    var body: some View {
        VStack {
            Spacer()
            Text(prompt)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 28)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 6)
                .animation(.spring(response: 0.7, dampingFraction: 0.88).delay(0.15), value: isVisible)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isVisible = true
            }
        }
    }
}

#Preview {
    PersonalEmptyStateView(prompt: "What’s on your mind today?")
}



