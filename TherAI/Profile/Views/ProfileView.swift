import SwiftUI

struct ProfileView: View {

    @Binding var isPresented: Bool

    @State private var showContent = false
    @State private var showCards = false
    @State private var showTogetherCapsule = false

    @EnvironmentObject private var sessionsVM: ChatSessionsViewModel
    @StateObject private var healthVM = ProfileViewModel()

    private let data: ProfileData = ProfileData.load()

    let profileNamespace: Namespace.ID
    let linkedMonthYear: String?

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
                        .stroke(Color.white.opacity(0.9), lineWidth: 2)
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
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        HStack {
                            Spacer()
                            Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { isPresented = false } }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }

                        ZStack {
                            avatarCircle(url: sessionsVM.partnerAvatarURL, size: 84)
                                .offset(x: 30)
                                .matchedGeometryEffect(id: "avatarPartner", in: profileNamespace)

                            avatarCircle(url: sessionsVM.myAvatarURL, size: 84)
                                .offset(x: -30)
                                .matchedGeometryEffect(id: "avatarUser", in: profileNamespace)
                        }
                        .padding(.top, -24)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        if showTogetherCapsule, let monthYear = linkedMonthYear {
                            HStack {
                                Spacer(minLength: 0)
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                                        .font(.system(size: 12))
                                    Text("Together since \(monthYear)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.12), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                                )
                                Spacer(minLength: 0)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if showCards {
                            RelationshipHealthView(
                                isExpanded: healthVM.isHealthExpanded,
                                onTap: { healthVM.toggleHealth() }
                            )
                            .environmentObject(healthVM)
                            .task { await healthVM.maybeRefreshOnAppear() }

                            RelationshipStatisticsView()
                                .environmentObject(healthVM)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .background(Color.clear)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .padding(.bottom, 12)
            .overlay(alignment: .top) { StatusBarBackground(showsDivider: false) }
            .onAppear {
                showTogetherCapsule = false
                showCards = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(
                        .spring(response: 0.28, dampingFraction: 0.94)
                    ) {
                        showTogetherCapsule = true
                        showCards = true
                    }
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .animation(.spring(response: 0.32, dampingFraction: 0.92, blendDuration: 0), value: isPresented)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @Namespace var namespace

    ProfileView(
        isPresented: $isPresented,
        profileNamespace: namespace,
        linkedMonthYear: "October 2025"
    )
    .environmentObject(ChatSessionsViewModel())
}
