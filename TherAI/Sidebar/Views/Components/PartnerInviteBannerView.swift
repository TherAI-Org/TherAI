import SwiftUI
import UIKit

struct PartnerInviteBannerView: View {
    @EnvironmentObject private var linkVM: LinkViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var copied: Bool = false

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.26, green: 0.58, blue: 1.00),
                Color(red: 0.63, green: 0.32, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentGradient)
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect with your partner")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Share your invite to unlock shared sessions and partner messages.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            linkRowOrButton()
        }
        .padding(14)
        .background(
            ZStack {
                // Soft material base
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                // Subtle accent gradient wash
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.26, green: 0.58, blue: 1.00).opacity(colorScheme == .dark ? 0.10 : 0.06),
                                Color(red: 0.63, green: 0.32, blue: 0.98).opacity(colorScheme == .dark ? 0.12 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    (colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06), radius: 12, x: 0, y: 6)
        .onAppear {
            Task { await linkVM.ensureInviteReady() }
        }
    }

    @ViewBuilder
    private func linkRowOrButton() -> some View {
        switch linkVM.state {
        case .creating:
            HStack {
                Spacer()
                ProgressView("Preparing link…")
                Spacer()
            }
        case .shareReady(let url):
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .medium))
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

                ShareLink(item: url) { IconButtonLabelView(systemName: "square.and.arrow.up") }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: colorScheme == .dark ? 0.14 : 0.96),
                                Color(white: colorScheme == .dark ? 0.18 : 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 6, x: 0, y: 3)
        case .linked:
            EmptyView()
        case .accepting, .unlinking:
            HStack {
                Spacer()
                ProgressView("Working…")
                Spacer()
            }
        case .idle, .unlinked, .error:
            Button(action: {
                Haptics.impact(.light)
                Task { await linkVM.ensureInviteReady() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Get invite link")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
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

#Preview {
    VStack(spacing: 16) {
        PartnerInviteBannerView()
            .environmentObject(LinkViewModel.preview(state: .shareReady(url: URL(string: "https://example.com/link?code=abc")!)))
            .padding()
        PartnerInviteBannerView()
            .environmentObject(LinkViewModel.preview(state: .creating))
            .padding()
    }
}


