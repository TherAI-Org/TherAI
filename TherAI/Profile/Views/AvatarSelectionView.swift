import SwiftUI

struct AvatarSelectionView: View {
    @Binding var isPresented: Bool

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

            SettingsAvatarPickerView(viewModel: SettingsViewModel())
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
}
