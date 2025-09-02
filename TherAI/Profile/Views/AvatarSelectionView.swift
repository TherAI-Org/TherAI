import SwiftUI

struct AvatarSelectionView: View {

    @StateObject private var viewModel = AvatarSelectionViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose your avatar")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(viewModel.options.prefix(4)) { option in
                        CartoonAvatarOptionView(
                            emoji: option.emoji,
                            color: AvatarOption.color(for: option.id),
                            isSelected: viewModel.selectedId == option.id,
                            onTap: { viewModel.select(id: option.id) }
                        )
                    }
                }

                HStack(spacing: 12) {
                    ForEach(viewModel.options.dropFirst(4).prefix(4)) { option in
                        CartoonAvatarOptionView(
                            emoji: option.emoji,
                            color: AvatarOption.color(for: option.id),
                            isSelected: viewModel.selectedId == option.id,
                            onTap: { viewModel.select(id: option.id) }
                        )
                    }
                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.pink.opacity(0.2), .blue.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.pink.opacity(0.4), .blue.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )

                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.pink)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemBackground).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }
}

struct CartoonAvatarOptionView: View {
    let emoji: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color,
                                color.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Text(emoji)
                    .font(.system(size: 28))

                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 66, height: 66)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.pink.opacity(0.6), .blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 70, height: 70)
                }
            }
        }
    }
}

#Preview {
    AvatarSelectionView()
        .padding(20)
}


