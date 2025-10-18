import SwiftUI

struct LinkPartnerInlineRow: View {
    @ObservedObject var linkViewModel: LinkViewModel

    var body: some View {
        VStack(spacing: 0) {
            switch linkViewModel.state {
            case .linked:
                HStack(spacing: 8) {
                    let name = UserDefaults.standard.string(forKey: PreferenceKeys.partnerName)
                    let avatarURL = UserDefaults.standard.string(forKey: PreferenceKeys.partnerAvatarURL)

                    Text("Connected with")
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

                        Text(name ?? "Partner")
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
            case .shareReady:
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 20, height: 20)
                    Text("Invite ready to share")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            case .idle, .unlinked, .error:
                HStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                    Text("Not linked")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Color(.systemBackground))
    }
}
