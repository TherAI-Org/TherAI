import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    let profileNamespace: Namespace.ID

    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var linkVM: LinkViewModel

    @State private var showCards = false
    @State private var showSubtitleCapsule = false

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

                        // Animated settings emblem
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
                                .matchedGeometryEffect(id: "settingsEmblem", in: profileNamespace)

                            Image(systemName: "gearshape")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.white)
                                .matchedGeometryEffect(id: "settingsGearIcon", in: profileNamespace)
                        }
                        .padding(.top, -24)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        // Subtitle capsule
                        if showSubtitleCapsule {
                            HStack {
                                Spacer(minLength: 0)
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.3")
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                        .font(.system(size: 12))
                                    Text("Customize your experience")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.12), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                                )
                                Spacer(minLength: 0)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if showCards {
                            // Render settings sections as premium cards
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
                .background(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .navigationDestination(item: $viewModel.destination) { destination in
                    switch destination {
                    case .link:
                        MainLinkView(viewModel: linkVM)
                            .navigationTitle("Link Your Partner")
                            .navigationBarTitleDisplayMode(.inline)
                    case .appearance:
                        AppearancePickerView(
                            current: {
                                let value = viewModel.currentAppearance
                                if value == "Light" { return .light }
                                if value == "Dark" { return .dark }
                                return .system
                            }(),
                            onSelect: { option in
                                viewModel.selectAppearance(option.rawValue)
                            }
                        )
                    case .avatar:
                        SettingsAvatarPickerView(viewModel: viewModel)
                            .navigationTitle("Change Avatar")
                            .navigationBarTitleDisplayMode(.inline)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(.bottom, 12)
        .overlay(alignment: .top) { StatusBarBackground(showsDivider: false) }
        .onAppear {
            showSubtitleCapsule = false
            showCards = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
                    showSubtitleCapsule = true
                    showCards = true
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.9, blendDuration: 0), value: isPresented)
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
}
