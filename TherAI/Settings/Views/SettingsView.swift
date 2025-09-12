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
                switch destination {
                case .link:
                    MainLinkView(viewModel: linkVM)
                        .navigationTitle("Link Your Partner")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            }
        }
    }
}


#Preview {
    SettingsView()
}
