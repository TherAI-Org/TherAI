import SwiftUI

struct SettingRowView: View {
    let setting: SettingItem
    let isLast: Bool
    let onToggle: () -> Void
    let onAction: () -> Void
    let onPickerSelect: ((String) -> Void)?

    init(
        setting: SettingItem,
        isLast: Bool,
        onToggle: @escaping () -> Void,
        onAction: @escaping () -> Void,
        onPickerSelect: ((String) -> Void)? = nil
    ) {
        self.setting = setting
        self.isLast = isLast
        self.onToggle = onToggle
        self.onAction = onAction
        self.onPickerSelect = onPickerSelect
    }

    var body: some View {
        Group {
            if case .picker(let options) = setting.type {
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
                                .hidden() // keep height consistent but hide subtitle when menu is used
                        }
                    }
                    
                    Spacer()
                    
                    Menu {
                        ForEach(options, id: \.self) { option in
                            Button(action: { onPickerSelect?(option) }) {
                                HStack {
                                    Text(option)
                                    if option == (setting.subtitle ?? "") {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(setting.subtitle ?? "")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            } else if case .toggle = setting.type {
                // Dedicated layout for toggle rows: no outer Button, real Binding
                HStack(spacing: 12) {
                    Image(systemName: setting.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .frame(width: 24, height: 24)

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

                    let currentIsOn: Bool = {
                        if case .toggle(let isOn) = setting.type { return isOn }
                        return false
                    }()

                    Toggle("", isOn: Binding(
                        get: { currentIsOn },
                        set: { newValue in
                            if newValue != currentIsOn { onToggle() }
                        }
                    ))
                    .labelsHidden()
                    .tint(.accentColor)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            } else {
                Button(action: {
                    switch setting.type {
                    case .toggle:
                        onToggle()
                    case .navigation, .action:
                        onAction()
                    case .picker:
                        break
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
                    EmptyView()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        
        if !isLast {
            Divider()
                .padding(.leading, 52)
        }
    }
}

// Preview removed to prevent build-time initializer mismatches during codegen.
