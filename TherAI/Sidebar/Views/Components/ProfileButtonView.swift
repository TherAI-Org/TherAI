import SwiftUI

struct ProfileButtonView: View {

    let profileNamespace: Namespace.ID

    var compact: Bool = false

    var body: some View {
        if compact {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.72, green: 0.37, blue: 0.98),
                                    Color(red: 0.38, green: 0.65, blue: 1.00)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .overlay(
                            Text("S")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                        .offset(x: 20)
                        .matchedGeometryEffect(id: "avatarPartner", in: profileNamespace)

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
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        )
                        .overlay(
                            Text("M")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                        .offset(x: -20)
                        .matchedGeometryEffect(id: "avatarUser", in: profileNamespace)
                }
                .padding(.leading, 16)
            }
        } else {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.72, green: 0.37, blue: 0.98),
                                    Color(red: 0.38, green: 0.65, blue: 1.00)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                        .overlay(
                            Text("S")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                        .offset(x: 24)
                        .matchedGeometryEffect(id: "avatarPartner", in: profileNamespace)

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
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                        .overlay(
                            Text("M")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
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


