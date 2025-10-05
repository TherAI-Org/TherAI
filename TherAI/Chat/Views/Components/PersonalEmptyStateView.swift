import SwiftUI

struct PersonalEmptyStateView: View {
    let prompt: String
    @State private var isVisible: Bool = false

    var body: some View {
        GeometryReader { geometry in
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
            .frame(height: geometry.size.height)
        }
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



