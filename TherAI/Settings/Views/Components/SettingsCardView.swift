import SwiftUI

struct SettingsCardView: View {
    let section: SettingsSection
    let onToggle: (Int) -> Void
    let onAction: (Int) -> Void
    let onPickerSelect: ((Int, String) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section Header - iOS Settings style
            HStack {
                Text(section.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
            
            // Settings Items in grouped card
            VStack(spacing: 0) {
                ForEach(Array(section.settings.enumerated()), id: \.offset) { index, setting in
                    SettingRowView(
                        setting: setting,
                        isLast: index == section.settings.count - 1,
                        onToggle: { onToggle(index) },
                        onAction: { onAction(index) },
                        onPickerSelect: { value in onPickerSelect?(index, value) }
                    )
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Section Footer (if needed)
            if shouldShowFooter() {
                HStack {
                    Text(getFooterText())
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
        }
    }
    
    private func shouldShowFooter() -> Bool {
        switch section.title {
        case "Privacy & Data":
            return true
        case "About":
            return true
        default:
            return false
        }
    }
    
    private func getFooterText() -> String {
        switch section.title {
        case "Privacy & Data":
            return "Clearing chat history will also reset relationship insights after the app refreshes."
        case "About":
            return "TherAI helps couples strengthen their relationships through AI-powered insights and communication tools."
        default:
            return ""
        }
    }
}

#Preview {
    SettingsCardView(
        section: SettingsSection(
            title: "App Settings",
            icon: "gear",
            gradient: [Color.blue, Color.purple],
            settings: [
                SettingItem(title: "Notifications", subtitle: "Push notifications", type: .toggle(true), icon: "bell"),
                SettingItem(title: "Dark Mode", subtitle: "Use dark appearance", type: .toggle(false), icon: "moon")
            ]
        ),
        onToggle: { _ in },
        onAction: { _ in },
        onPickerSelect: { _, _ in }
    )
    .padding(20)
}
