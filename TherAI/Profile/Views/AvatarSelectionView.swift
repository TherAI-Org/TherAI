import SwiftUI

struct AvatarSelectionView: View {

    @StateObject private var viewModel = AvatarSelectionViewModel()
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Header with title and close button
            HStack {
                Text("Choose Avatar")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    viewModel.cancel()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
            }

            // Avatar grid with proper spacing
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ForEach(viewModel.options.prefix(4)) { option in
                        CartoonAvatarOptionView(
                            emoji: option.emoji,
                            color: AvatarOption.color(for: option.id),
                            isSelected: viewModel.selectedId == option.id,
                            onTap: { viewModel.select(id: option.id) }
                        )
                    }
                }

                HStack(spacing: 16) {
                    ForEach(viewModel.options.dropFirst(4).prefix(3)) { option in
                        CartoonAvatarOptionView(
                            emoji: option.emoji,
                            color: AvatarOption.color(for: option.id),
                            isSelected: viewModel.selectedId == option.id,
                            onTap: { viewModel.select(id: option.id) }
                        )
                    }
                    
                    // Add more button with Apple-style design
                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )

                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Action buttons with Apple-style design
            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.cancel()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .font(.system(size: 16, weight: .medium))
                .cornerRadius(12)
                
                Button("Save") {
                    viewModel.save()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    viewModel.hasChanges ? 
                    LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom) :
                    LinearGradient(colors: [Color(.systemGray4)], startPoint: .top, endPoint: .bottom)
                )
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))
                .cornerRadius(12)
                .disabled(!viewModel.hasChanges)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
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
                    .frame(width: 52, height: 52)

                Text(emoji)
                    .font(.system(size: 24))

                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 2.5)
                        .frame(width: 56, height: 56)

                    Circle()
                        .stroke(
                            Color.blue,
                            lineWidth: 2
                        )
                        .frame(width: 58, height: 58)
                }
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    AvatarSelectionView(isPresented: .constant(true))
        .padding(20)
}


