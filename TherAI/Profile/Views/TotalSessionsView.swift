import SwiftUI

struct TotalSessionsView: View {
	let totalSessions: Int
	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		HStack(spacing: 16) {
			ZStack {
				Circle()
					.fill(
						LinearGradient(
							colors: [.blue, .blue.opacity(0.7)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.frame(width: 48, height: 48)

				Image(systemName: "calendar.badge.clock")
					.font(.system(size: 20, weight: .medium))
					.foregroundColor(.white)
			}

			VStack(alignment: .leading, spacing: 4) {
				Text("Total Sessions")
					.font(.system(size: 16, weight: .medium))
					.foregroundColor(.secondary)

				Text("\(totalSessions)")
					.font(.system(size: 28, weight: .bold, design: .rounded))
					.foregroundColor(.primary)
			}

			Spacer()
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 16)
		.background(
			RoundedRectangle(cornerRadius: 16)
				.fill(colorScheme == .light ? Color.white : Color(.systemGray6))
				.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
		)
	}
}


#Preview {
	TotalSessionsView(totalSessions: 24)
		.padding(20)
}



