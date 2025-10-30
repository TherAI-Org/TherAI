import SwiftUI

struct LinkPartnerInlineRow: View {
    @ObservedObject var linkViewModel: LinkViewModel
    @State private var copied: Bool = false
    @AppStorage(PreferenceKeys.partnerName) private var cachedPartnerName: String = ""
    @AppStorage(PreferenceKeys.partnerAvatarURL) private var cachedPartnerAvatarURL: String = ""

    var body: some View {
        VStack(spacing: 0) {
            switch linkViewModel.state {
            case .linked:
                HStack(spacing: 8) {
                    // Use helper function that prioritizes user-entered partner_display_name
                    let name = PreferenceKeys.getPartnerDisplayName()
                    let avatarURL: String? = {
                        let trimmed = cachedPartnerAvatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? UserDefaults.standard.string(forKey: PreferenceKeys.partnerAvatarURL) : trimmed
                    }()

                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 20, height: 20)

                    Text("Connected to")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        AvatarCacheManager.shared.cachedAsyncImage(
                            urlString: avatarURL,
                            placeholder: {
                                AnyView(
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.gray)
                                        )
                                )
                            },
                            fallback: {
                                AnyView(
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.gray)
                                        )
                                )
                            }
                        )
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())

                        Text(name)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            case .creating, .accepting, .unlinking:
                HStack {
                    Spacer()
                    ProgressView()
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            case .shareReady(let url):
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 20, height: 20)

                    Text(truncatedDisplay(for: url))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button(action: {
                        UIPasteboard.general.string = url.absoluteString
                        withAnimation(.easeInOut(duration: 0.15)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.15)) { copied = false }
                        }
                    }) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(PlainButtonStyle())

                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 34, height: 34)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            case .idle, .unlinked, .error:
                // When not linked or after unlink, ensure invite is prepared and show MainLinkView
                HStack {
                    Spacer()
                    ProgressView("Preparing link…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .onAppear { Task { await linkViewModel.ensureInviteReady() } }
            }
        }
        .background(Color(.systemBackground))
    }
}

private func truncatedDisplay(for url: URL) -> String {
    let host = url.host ?? ""
    let path = url.path
    if host.isEmpty && path.isEmpty { return "Invite link" }
    let shortPath = path.isEmpty ? "…" : "/…"
    return host.isEmpty ? "link://\(shortPath)" : "\(host)\(shortPath)"
}
