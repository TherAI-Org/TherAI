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
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: setting.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                
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
                        .onTapGesture {
                            onToggle()
                        }
                case .navigation:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                case .action:
                    if setting.title == "Sign Out" {
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                case .picker:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
        
        if !isLast {
            Divider()
                .padding(.leading, 68)
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
