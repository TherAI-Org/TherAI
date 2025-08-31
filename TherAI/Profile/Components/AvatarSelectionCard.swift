import SwiftUI

// MARK: - Enhanced Avatar Selection Card
struct AvatarSelectionCard: View {
    @State private var selectedAvatar: Int = 0
    
    private let cartoonCharacters = [
        "🐱", "🐶", "🐰", "🐼", "🐨", "🦊", "🐯", "🦁", "🐸", "🐙"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose your avatar")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Top row - 4 avatars
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        CartoonAvatarOption(
                            emoji: cartoonCharacters[index],
                            index: index,
                            isSelected: selectedAvatar == index,
                            onTap: { selectedAvatar = index }
                        )
                    }
                }
                
                // Bottom row - 4 avatars + plus button
                HStack(spacing: 12) {
                    ForEach(4..<8, id: \.self) { index in
                        CartoonAvatarOption(
                            emoji: cartoonCharacters[index],
                            index: index,
                            isSelected: selectedAvatar == index,
                            onTap: { selectedAvatar = index }
                        )
                    }
                    
                    // Enhanced plus button for custom avatar
                    Button(action: {
                        // Add custom avatar functionality
                    }) {
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

// MARK: - Cartoon Avatar Option
struct CartoonAvatarOption: View {
    let emoji: String
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    private let avatarColors: [Color] = [
        .blue, .pink, .purple, .orange, .green, .red, .yellow, .teal
    ]
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                avatarColors[index % avatarColors.count],
                                avatarColors[index % avatarColors.count].opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Text(emoji)
                    .font(.system(size: 28))
                
                // Selection indicator
                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 66, height: 66)
                    
                    // Glow effect
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
    AvatarSelectionCard()
        .padding(20)
}
