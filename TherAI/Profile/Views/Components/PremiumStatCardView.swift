// View is nowhere to be used, consider deleting in the future.



import SwiftUI

struct PremiumStatCardView: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
        )
    }
}


#Preview {
    HStack(spacing: 12) {
        PremiumStatCardView(title: "Avg Rating", value: "4.8", icon: "star.fill", gradient: [.yellow, .orange])
        PremiumStatCardView(title: "New Sessions", value: "3", icon: "plus", gradient: [.blue, .purple])
    }
    .padding(20)
}


