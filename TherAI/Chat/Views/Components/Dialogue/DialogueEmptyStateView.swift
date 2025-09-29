import SwiftUI

struct DialogueEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Start a meaningful dialogue with TherAI")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Discuss what’s on your mind with TherAI first. When you're ready, we can help you share a thoughtful, caring message with your partner.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    DialogueEmptyStateView()
}



