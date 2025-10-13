import SwiftUI

struct SettingRowView: View {
    let setting: SettingItem
    let isLast: Bool
    let onToggle: () -> Void
    let onAction: () -> Void
    let onPickerSelect: ((String) -> Void)?
    @EnvironmentObject var linkVM: LinkViewModel

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
            if case .linkPartner = setting.type {
                LinkPartnerSettingRow(
                    setting: setting,
                    isLast: isLast,
                    linkViewModel: linkVM
                )
            } else if case .picker(let options) = setting.type {
                HStack(spacing: 12) {
                    // Icon - iOS Settings style
                    Image(systemName: setting.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 2) {
                        Text(setting.title)
                            .font(.system(size: 16, weight: .regular))
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            } else if case .toggle = setting.type {
                // Dedicated layout for toggle rows: no outer Button, real Binding
                HStack(spacing: 12) {
                    Image(systemName: setting.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(setting.title)
                            .font(.system(size: 16, weight: .regular))
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
                    .tint(.green)
                }
                .padding(.horizontal, 16)
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
                    case .linkPartner:
                        // Handled by LinkPartnerSettingRow
                        break
                    }
                }) {
                    HStack(spacing: 12) {
                        // Icon - iOS Settings style
                        Image(systemName: setting.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 24, height: 24)
                        
                        // Content
                        VStack(alignment: .leading, spacing: 2) {
                            Text(setting.title)
                                .font(.system(size: 16, weight: .regular))
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
                                .tint(.green)
                                .onTapGesture {
                                    onToggle()
                                }
                        case .navigation:
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        case .action:
                            if setting.title == "Sign Out" {
                                Text("Sign Out")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        case .picker:
                            EmptyView()
                        case .linkPartner:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
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

struct LinkPartnerSettingRow: View {
    let setting: SettingItem
    let isLast: Bool
    @ObservedObject var linkViewModel: LinkViewModel
    @State private var copied: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: setting.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(setting.title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Content based on state
            switch linkViewModel.state {
            case .idle:
                HStack {
                    Spacer()
                    ProgressView("Preparing link…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 16)

            case .creating:
                HStack {
                    Spacer()
                    ProgressView("Creating link…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 16)

            case .shareReady(let url):
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))

                        Text(truncatedDisplay(for: url))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button(action: {
                            UIPasteboard.general.string = url.absoluteString
                            withAnimation(.easeInOut(duration: 0.15)) { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation(.easeInOut(duration: 0.15)) { copied = false }
                            }
                        }) {
                            IconButtonLabelView(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Share button
                        ShareLink(item: url) { IconButtonLabelView(systemName: "square.and.arrow.up") }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            case .accepting:
                HStack {
                    Spacer()
                    ProgressView("Linking…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 16)

            case .linked:
                VStack(spacing: 12) {
                    Label("Linked successfully", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button(action: {
                        Task { await linkViewModel.unlink() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "link.badge.minus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Unlink")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            case .error(let message):
                VStack(spacing: 10) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        Task { await linkViewModel.createInviteLink() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Try again")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            case .unlinking:
                HStack {
                    Spacer()
                    ProgressView("Unlinking…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 16)

            case .unlinked:
                HStack {
                    Spacer()
                    ProgressView("Preparing link…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            Task {
                await linkViewModel.ensureInviteReady()
            }
        }
    }
    
    private var shouldShowExpandedContent: Bool {
        switch linkViewModel.state {
        case .shareReady, .linked, .error:
            return true
        default:
            return false
        }
    }
    
    private func truncatedDisplay(for url: URL) -> String {
        let host = url.host ?? ""
        let path = url.path
        if host.isEmpty && path.isEmpty { return "Invite link" }
        let shortPath = path.isEmpty ? "…" : "/…"
        return host.isEmpty ? "link://\(shortPath)" : "\(host)\(shortPath)"
    }
}
