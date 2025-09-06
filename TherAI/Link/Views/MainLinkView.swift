import SwiftUI

struct MainLinkView: View {
    @StateObject private var viewModel: LinkViewModel

    init(accessTokenProvider: @escaping () async throws -> String) {
        _viewModel = StateObject(wrappedValue: LinkViewModel(accessTokenProvider: accessTokenProvider))
    }

    // Convenience initializer for previews
    init(viewModel: LinkViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            switch viewModel.state {
            case .idle:
                Text("Not linked")
                Button("Create link") {
                    Task { await viewModel.createInviteLink() }
                }

            case .creating:
                ProgressView("Creating link…")

            case .shareReady(let url):
                Text("Share this link with your partner:")
                Text(url.absoluteString).font(.footnote).multilineTextAlignment(.center)
                ShareLink(item: url) {
                    Label("Share link", systemImage: "square.and.arrow.up")
                }

            case .accepting:
                ProgressView("Linking…")

            case .linked:
                Label("Linked successfully", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                Button(role: .destructive) {
                    Task { await viewModel.unlink() }
                } label: {
                    Label("Unlink", systemImage: "link.badge.minus")
                }

            case .error(let message):
                VStack(spacing: 8) {
                    Label(message, systemImage: "exclamationmark.triangle").foregroundColor(.orange)
                    Button("Try again") {
                        Task { await viewModel.createInviteLink() }
                    }
                }
            case .unlinking:
                ProgressView("Unlinking…")
            case .unlinked:
                Label("Unlinked", systemImage: "link.slash").foregroundColor(.secondary)
                Button("Create link") {
                    Task { await viewModel.createInviteLink() }
                }
            }
        }
        .padding()
        .task { await viewModel.refreshStatus() }
    }
}

#if DEBUG
struct MainLinkView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Group {
                    Text("Idle / Not Linked").font(.headline)
                    MainLinkView(viewModel: .preview(state: .idle))
                }

                Divider()

                Group {
                    Text("Linked / Unlink Button").font(.headline)
                    MainLinkView(viewModel: .preview(state: .linked))
                }

                Divider()

                Group {
                    Text("Share Ready / Share Button").font(.headline)
                    MainLinkView(viewModel: .preview(state: .shareReady(url: URL(string: "https://example.com/invite/abc123")!)))
                }

                Divider()

                Group {
                    Text("Unlinked / Create Link").font(.headline)
                    MainLinkView(viewModel: .preview(state: .unlinked))
                }
            }
            .padding()
        }
        .previewDisplayName("MainLinkView – All Key States")
        .previewLayout(.sizeThatFits)
    }
}
#endif
