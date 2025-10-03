import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    let profileNamespace: Namespace.ID

    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var linkVM: LinkViewModel
    @EnvironmentObject private var sessionsVM: ChatSessionsViewModel

    @State private var showCards = false
    @State private var showSubtitleCapsule = false
    @State private var showingAvatarSelection = false
    @State private var previewEmoji: String? = nil
    @State private var previewImageData: Data? = nil
    @State private var showSaveButton = false

    var body: some View {
        ZStack {
            // Foreground content matching profile overlay behavior
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Close button
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    isPresented = false
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }

                        // User avatar (or settings emblem)
                        ZStack {
                            // Background: Always render saved avatar or default
                            if let urlStr = sessionsVM.myAvatarURL, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Color.clear
                                }
                                .frame(width: 84, height: 84)
                                .clipShape(Circle())
                                .matchedGeometryEffect(id: "settingsGearIcon", in: profileNamespace)
                            } else {
                                // Gradient background for default icon
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.26, green: 0.58, blue: 1.00),
                                                Color(red: 0.63, green: 0.32, blue: 0.98)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 84, height: 84)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                    )
                                    .matchedGeometryEffect(id: "settingsEmblem", in: profileNamespace)

                                Image(systemName: "gearshape")
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            // Foreground: Preview overlays on top when selected
                            if let emoji = previewEmoji {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.26, green: 0.58, blue: 1.00),
                                                    Color(red: 0.63, green: 0.32, blue: 0.98)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 84, height: 84)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                        )

                                    Text(emoji)
                                        .font(.system(size: 48))
                                }
                                .transition(.opacity)
                            } else if let imageData = previewImageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(Circle())
                                    .transition(.opacity)
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: previewEmoji)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: previewImageData)
                        .padding(.top, -24)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        // Edit Avatar button
                        if showSubtitleCapsule {
                            HStack {
                                Spacer(minLength: 0)
                                Button(action: {
                                    if showingAvatarSelection {
                                        // Clear unsaved selections when closing
                                        previewEmoji = nil
                                        previewImageData = nil
                                        showSaveButton = false
                                    }
                                    Haptics.impact(.light)
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        showingAvatarSelection.toggle()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: showingAvatarSelection ? "chevron.up.circle.fill" : "person.2.circle")
                                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Edit Avatar")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(showingAvatarSelection ? Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.1) : Color(.systemGray6))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(showingAvatarSelection ? 0.4 : 0.12), lineWidth: showingAvatarSelection ? 2 : 1)
                                            )
                                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                Spacer(minLength: 0)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .zIndex(2)
                        }

                        // Settings cards sections
                        if showCards {
                            VStack(spacing: 24) {
                                ForEach(Array(viewModel.settingsSections.enumerated()), id: \.offset) { sectionIndex, section in
                                    SettingsCardView(
                                        section: section,
                                        onToggle: { settingIndex in
                                            viewModel.toggleSetting(for: sectionIndex, settingIndex: settingIndex)
                                        },
                                        onAction: { settingIndex in
                                            viewModel.handleSettingAction(for: sectionIndex, settingIndex: settingIndex)
                                        },
                                        onPickerSelect: { settingIndex, value in
                                            viewModel.handlePickerSelection(for: sectionIndex, settingIndex: settingIndex, value: value)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(showingAvatarSelection)
                .background(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.2), value: showingAvatarSelection)
                .navigationDestination(item: $viewModel.destination) { destination in
                    MainLinkView(viewModel: linkVM)
                        .navigationTitle("Link Your Partner")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .padding(.bottom, 12)
        .animation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0), value: isPresented)
        .overlay(alignment: .top) {
            StatusBarBackground(showsDivider: false)
        }
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                if showingAvatarSelection {
                    // Tap to dismiss background
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Clear unsaved selections
                            previewEmoji = nil
                            previewImageData = nil
                            showSaveButton = false
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                showingAvatarSelection = false
                            }
                        }
                }

                VStack(spacing: 0) {
                    // Spacer to position below header
                    Color.clear
                        .frame(height: 180)

                        CompactAvatarPickerView(
                            viewModel: viewModel,
                            isPresented: $showingAvatarSelection,
                            selectedEmoji: $previewEmoji,
                            uploadedImageData: $previewImageData,
                            showSaveButton: $showSaveButton
                        )
                        .padding(.horizontal, 16)
                        .scaleEffect(showingAvatarSelection ? 1.0 : 0.5)

                    Spacer()
                }
                .allowsHitTesting(showingAvatarSelection)

                // Save button on top of everything (exception to tap-to-dismiss)
                if showSaveButton {
                    HStack {
                        Button(action: {
                            // Close immediately
                            showSaveButton = false
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                showingAvatarSelection = false
                            }

                            // Upload in background
                            Task {
                                if let emoji = previewEmoji {
                                    if let emojiImage = generateEmojiImage(emoji: emoji) {
                                        await viewModel.uploadAvatar(data: emojiImage)
                                        await sessionsVM.loadPairedAvatars()
                                    }
                                } else if let data = previewImageData {
                                    await viewModel.uploadAvatar(data: data)
                                    await sessionsVM.loadPairedAvatars()
                                }
                            }
                        }) {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                .padding(12)
                        }
                        .padding(.leading, 8)

                        Spacer()
                    }
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showingAvatarSelection)
            .zIndex(showingAvatarSelection ? 1 : -1)
            .opacity(showingAvatarSelection ? 1.0 : 0.0)
        }
        .onAppear {
            // Clear any preview states when Settings view appears
            previewEmoji = nil
            previewImageData = nil
            showSaveButton = false
            showSubtitleCapsule = false
            showCards = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                    showSubtitleCapsule = true
                    showCards = true
                }
            }
        }
    }

    // Helper to generate image from emoji
    private func generateEmojiImage(emoji: String) -> Data? {
        let size: CGFloat = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            // Draw gradient background
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.26, green: 0.58, blue: 1.00, alpha: 1.0).cgColor,
                    UIColor(red: 0.63, green: 0.32, blue: 0.98, alpha: 1.0).cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size, y: size),
                options: []
            )

            // Draw emoji
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.6),
                .paragraphStyle: paragraphStyle
            ]
            let emojiSize = (emoji as NSString).size(withAttributes: attributes)
            let rect = CGRect(
                x: (size - emojiSize.width) / 2,
                y: (size - emojiSize.height) / 2,
                width: emojiSize.width,
                height: emojiSize.height
            )
            (emoji as NSString).draw(in: rect, withAttributes: attributes)
        }
        return image.jpegData(compressionQuality: 0.9)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @Namespace var namespace

    SettingsView(
        isPresented: $isPresented,
        profileNamespace: namespace
    )
    .environmentObject(LinkViewModel(accessTokenProvider: {
        return "mock-access-token"
    }))
    .environmentObject(ChatSessionsViewModel())
}
