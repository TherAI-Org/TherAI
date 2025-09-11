import SwiftUI

struct SettingRowView: View {
    let setting: SettingItem
    let isLast: Bool
    let onToggle: () -> Void
    let onAction: () -> Void
    
    var body: some View {
        Button(action: {
            switch setting.type {
            case .toggle:
                onToggle()
            case .navigation, .action:
                onAction()
            case .picker:
                onAction()
            }
        }) {
            HStack(spacing: 12) {
                // Icon - smaller, iOS Settings style
                Image(systemName: setting.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    .frame(width: 24, height: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(setting.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = setting.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                // Right side content
                switch setting.type {
                case .toggle(let isOn):
                    Toggle("", isOn: .constant(isOn))
                        .labelsHidden()
                        .tint(.accentColor)
                        .onTapGesture {
                            onToggle()
                        }
                case .navigation:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                case .action:
                    if setting.title == "Sign Out" {
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                case .picker:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
        
        if !isLast {
            Divider()
                .padding(.leading, 52)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        SettingRowView(
            setting: SettingItem(title: "Notifications", subtitle: "Push notifications for new messages", type: .toggle(true), icon: "bell"),
            isLast: false,
            onToggle: {},
            onAction: {}
        )
        
        SettingRowView(
            setting: SettingItem(title: "Account Settings", subtitle: "Manage your account", type: .navigation, icon: "person.crop.circle"),
            isLast: true,
            onToggle: {},
            onAction: {}
        )
    }
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .padding(20)
}
