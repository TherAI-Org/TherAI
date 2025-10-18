import SwiftUI

struct ConnectionCapsuleView: View {
    let partnerName: String?
    let partnerAvatarURL: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            HStack(spacing: 8) {
                Text("Connected with")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black)

                HStack(spacing: 4) {
                    AvatarCacheManager.shared.cachedAsyncImage(
                        urlString: partnerAvatarURL,
                        placeholder: {
                            AnyView(
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 8, weight: .medium))
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
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.gray)
                                    )
                            )
                        }
                    )
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())

                    // Partner name
                    if let name = partnerName {
                        Text(name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    } else {
                        Text("Partner")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white)
                .overlay(
                    Capsule()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // With partner info
        ConnectionCapsuleView(
            partnerName: "Sarah Johnson",
            partnerAvatarURL: nil
        )

        // With avatar URL
        ConnectionCapsuleView(
            partnerName: "Alex Chen",
            partnerAvatarURL: "https://example.com/avatar.jpg"
        )

        // Show how it looks in context
        VStack(spacing: 8) {
            Text("John Doe")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            ConnectionCapsuleView(
                partnerName: "Emma Wilson",
                partnerAvatarURL: nil
            )
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
