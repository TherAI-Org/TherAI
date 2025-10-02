import SwiftUI

struct ProfileButtonView: View {

    let profileNamespace: Namespace.ID

    var compact: Bool = false
    @EnvironmentObject private var sessionsVM: ChatSessionsViewModel

    @ViewBuilder
    private func avatarCircle(url: String?, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.58, blue: 1.00),
                            Color(red: 0.63, green: 0.32, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: size > 50 ? 2 : 1)
                )

            if let urlStr = url, let u = URL(string: urlStr) {
                AsyncImage(url: u) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                        .tint(.white)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            }
        }
    }

    var body: some View {
        if compact {
            HStack {
                ZStack {
                    avatarCircle(url: sessionsVM.partnerAvatarURL, size: 50)
                        .offset(x: 20)
                        .matchedGeometryEffect(id: "avatarPartner", in: profileNamespace)

                    avatarCircle(url: sessionsVM.myAvatarURL, size: 50)
                        .offset(x: -20)
                        .matchedGeometryEffect(id: "avatarUser", in: profileNamespace)
                }
                .padding(.leading, 16)
            }
        } else {
            HStack {
                ZStack {
                    avatarCircle(url: sessionsVM.partnerAvatarURL, size: 56)
                        .offset(x: 24)
                        .matchedGeometryEffect(id: "avatarPartner", in: profileNamespace)

                    avatarCircle(url: sessionsVM.myAvatarURL, size: 56)
                        .offset(x: -24)
                        .matchedGeometryEffect(id: "avatarUser", in: profileNamespace)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 40)
            .padding(.trailing, 18)
            .padding(.vertical, 20)
        }
    }
}


