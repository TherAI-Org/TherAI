import SwiftUI
import PhotosUI

struct SettingsAvatarPickerView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selection: PhotosPickerItem? = nil
    @State private var previewImage: Image? = nil
    @State private var pickedData: Data? = nil

    var body: some View {
        VStack(spacing: 16) {
            if let image = previewImage {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 2))
                    .shadow(radius: 8)
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 160, height: 160)
                    .overlay(Text("Select Photo").foregroundColor(.secondary))
            }

            PhotosPicker(selection: $selection, matching: .images) {
                Text("Choose from Photos")
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .onChange(of: selection) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        pickedData = data
                        if let ui = UIImage(data: data) { previewImage = Image(uiImage: ui) }
                    }
                }
            }

            Button("Save") {
                if let data = pickedData { Task { await viewModel.uploadAvatar(data: data) } }
            }
            .disabled(pickedData == nil)
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(20)
    }
}



