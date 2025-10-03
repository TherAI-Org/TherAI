import SwiftUI
import PhotosUI

struct CompactAvatarPickerView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var sessionsVM: ChatSessionsViewModel
    @State private var selection: PhotosPickerItem? = nil
    @Binding var isPresented: Bool
    @Binding var selectedEmoji: String?
    @Binding var uploadedImageData: Data?
    @Binding var showSaveButton: Bool

    let emojiAvatars = ["🐻", "🦊", "🐨", "🦁", "🐼", "🦄"]

    var currentAvatarURL: String? {
        sessionsVM.myAvatarURL
    }

    var body: some View {
        VStack(spacing: 20) {
            // Emoji grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(emojiAvatars, id: \.self) { emoji in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedEmoji = emoji
                            uploadedImageData = nil
                            selection = nil
                            // Show Save button when emoji is selected
                            showSaveButton = true
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(
                                            selectedEmoji == emoji
                                                ? LinearGradient(
                                                    colors: [
                                                        Color(red: 0.26, green: 0.58, blue: 1.00),
                                                        Color(red: 0.63, green: 0.32, blue: 0.98)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                : LinearGradient(
                                                    colors: [Color(.systemGray5), Color(.systemGray5)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                            lineWidth: selectedEmoji == emoji ? 2.5 : 1.5
                                        )
                                )
                                .frame(height: 70)
                                .shadow(
                                    color: selectedEmoji == emoji
                                        ? Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.2)
                                        : Color.black.opacity(0.04),
                                    radius: selectedEmoji == emoji ? 10 : 3,
                                    x: 0,
                                    y: selectedEmoji == emoji ? 5 : 2
                                )

                            Text(emoji)
                                .font(.system(size: 36))
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 4)

            // Divider with "or"
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)

                Text("or")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
            }
            .padding(.horizontal, 30)

            // Upload button
            PhotosPicker(selection: $selection, matching: .images) {
                Text("Set New Photo")
                    .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 4)
            .onChange(of: selection) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            uploadedImageData = data
                            selectedEmoji = nil
                            // Always show Save for uploaded photos
                            showSaveButton = true
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.15), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}

// Custom button style for scale effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
