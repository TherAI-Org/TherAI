import SwiftUI

struct RelationshipStatisticsView: View {
    @Environment(\.colorScheme) private var colorScheme

    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            }

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .light ? Color.white : Color(.systemGray6))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statTile(title: "Communication", value: "Great", icon: "message.fill", color: Color(red: 0.26, green: 0.58, blue: 1.00))

                statTile(title: "Trust Level", value: "Strong", icon: "lock.shield.fill", color: .green)

                statTile(title: "Future Goals", value: "Aligned", icon: "target", color: Color(red: 0.63, green: 0.32, blue: 0.98))

                statTile(title: "Intimacy", value: "Deep", icon: "heart.fill", color: .pink)
            }
            .padding(.bottom, 16)
        }
    }
}


#Preview {
    RelationshipStatisticsView()
        .padding(20)
}


