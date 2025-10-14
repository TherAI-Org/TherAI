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
            } else if case .picker = setting.type {
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
                    }

                    Spacer()

                    EmptyView()
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

                    Toggle("", isOn: Binding(
                        get: {
                            if case .toggle(let isOn) = setting.type { return isOn }
                            return false
                        },
                        set: { _ in onToggle() }
                    ))
                    .labelsHidden()
                    .tint(.green)
                    .allowsHitTesting(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                // Do not add row-level onTap for toggle rows to avoid double toggles
            } else if case .navigation = setting.type {
                NavigationLink(destination: viewForTitle(setting.title)) {
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
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
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
                            if setting.title == "Sign Out" {
                                Text(setting.title)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                            } else {
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
                            EmptyView() // For actions, no trailing accessory; especially Sign Out
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
    }
}

// Preview removed to prevent build-time initializer mismatches during codegen.

@ViewBuilder
private func viewForTitle(_ title: String) -> some View {
    switch title {
    case "Contact Support":
        ContactSupportView()
    case "Privacy Policy":
        PrivacyPolicyView()
    default:
        EmptyView()
    }
}

struct LinkPartnerSettingRow: View {
    let setting: SettingItem
    let isLast: Bool
    @ObservedObject var linkViewModel: LinkViewModel
    @State private var copied: Bool = false

    var body: some View {
        VStack(spacing: 0) {
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
                .padding(.vertical, 12)

            case .creating:
                HStack {
                    Spacer()
                    ProgressView("Creating link…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)

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
                    .padding(10)
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
                .padding(.vertical, 12)

            case .accepting:
                HStack {
                    Spacer()
                    ProgressView("Linking…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)

            case .linked:
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16, weight: .semibold))

                    Text("Linked")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: {
                        Task { await linkViewModel.unlink() }
                    }) {
                        Text("Unlink")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

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
                .padding(.bottom, 12)

            case .unlinking:
                HStack {
                    Spacer()
                    ProgressView("Unlinking…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)

            case .unlinked:
                HStack {
                    Spacer()
                    ProgressView("Preparing link…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
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
