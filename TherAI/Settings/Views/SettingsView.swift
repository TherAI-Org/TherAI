import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    @EnvironmentObject private var linkVM: LinkViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            // Inline header with centered title and trailing close button
            ZStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .offset(x: -10)
                    .accessibilityLabel("Close")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                LazyVStack(spacing: 32) {
                    // Settings Sections with proper spacing
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

                    // Bottom spacing
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationDestination(item: $viewModel.destination) { destination in
                if destination == .link {
                    MainLinkView(viewModel: linkVM)
                        .navigationTitle("Link Your Partner")
                        .navigationBarTitleDisplayMode(.inline)
                } else if destination == .appearance {
                    AppearancePickerView(
                        current: mapToOption(viewModel.currentAppearance),
                        onSelect: { option in
                            viewModel.selectAppearance(option.rawValue)
                        }
                    )
                } else {
                    EmptyView()
                }
            }
            }
        }
        .background(Color.white.ignoresSafeArea())
    }
}

private func mapToOption(_ value: String) -> AppearanceOption {
    switch value {
    case "Light": return .light
    case "Dark": return .dark
    default: return .system
    }
}


#Preview {
    SettingsView()
}
