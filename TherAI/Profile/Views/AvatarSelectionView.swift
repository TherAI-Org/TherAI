import SwiftUI

struct AvatarSelectionView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var sessionsVM: ChatSessionsViewModel

    @State private var selectedEmoji: String? = nil
    @State private var uploadedImageData: Data? = nil
    @State private var showSaveButton = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isPresented = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(.top, 8)

            CompactAvatarPickerView(
                viewModel: viewModel,
                isPresented: $isPresented,
                selectedEmoji: $selectedEmoji,
                uploadedImageData: $uploadedImageData,
                showSaveButton: $showSaveButton
            )
            .environmentObject(sessionsVM)
            .frame(maxWidth: 520)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 24)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    AvatarSelectionView(isPresented: $isPresented)
        .environmentObject(ChatSessionsViewModel())
}
