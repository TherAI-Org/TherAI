import SwiftUI
import UIKit

struct MainLinkView: View {

    @StateObject private var viewModel: LinkViewModel

    @State private var copied: Bool = false

    init(accessTokenProvider: @escaping () async throws -> String) {
        _viewModel = StateObject(wrappedValue: LinkViewModel(accessTokenProvider: accessTokenProvider))
    }

    // Convenience initializer for previews
    init(viewModel: LinkViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 20) {
            switch viewModel.state {
            case .idle:
                MinimalCardView {
                    HStack {
                        Spacer()
                        ProgressView("Preparing link…")
                        Spacer()
                    }
                }

            case .creating:
                MinimalCardView {
                    HStack {
                        Spacer()
                        ProgressView("Creating link…")
                        Spacer()
                    }
                }

            case .shareReady(let url):
                MinimalCardView {
                    VStack(spacing: 12) {
                        Text("Invite link ready")
                            .font(.subheadline)
                            .foregroundColor(.primary)

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

                            // Share button
                            ShareLink(item: url) { IconButtonLabelView(systemName: "square.and.arrow.up") }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                }

            case .accepting:
                MinimalCardView {
                    HStack {
                        Spacer()
                        ProgressView("Linking…")
                        Spacer()
                    }
                }

            case .linked:
                MinimalCardView {
                    VStack(spacing: 12) {
                        Label("Linked successfully", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        MinimalButtonView(title: "Unlink", systemImage: "link.badge.minus", role: .destructive) {
                            Task { await viewModel.unlink() }
                        }
                    }
                }

            case .error(let message):
                MinimalCardView {
                    VStack(spacing: 10) {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        MinimalButtonView(title: "Try again", systemImage: "arrow.clockwise") {
                            Task { await viewModel.createInviteLink() }
                        }
                    }
                }

            case .unlinking:
                MinimalCardView {
                    HStack {
                        Spacer()
                        ProgressView("Unlinking…")
                        Spacer()
                    }
                }

            case .unlinked:
                MinimalCardView {
                    HStack {
                        Spacer()
                        ProgressView("Preparing link…")
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Helpers

private func truncatedDisplay(for url: URL) -> String {
    let host = url.host ?? ""
    let path = url.path
    if host.isEmpty && path.isEmpty { return "Invite link" }
    let shortPath = path.isEmpty ? "…" : "/…"
    return host.isEmpty ? "link://\(shortPath)" : "\(host)\(shortPath)"
}

#if DEBUG
struct MainLinkView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainLinkView(viewModel: .preview(state: .idle))
                .previewDisplayName("Idle")
                .padding()

            MainLinkView(viewModel: .preview(state: .shareReady(url: URL(string: "https://example.com/invite/abc123")!)))
                .previewDisplayName("Share Ready")
                .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
