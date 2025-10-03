import SwiftUI
import UIKit

struct InlineLinkCardView: View {
    @ObservedObject var linkViewModel: LinkViewModel
    @State private var copied: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                
                Text("Link Your Partner")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
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
                .padding(.bottom, 16)

            case .creating:
                HStack {
                    Spacer()
                    ProgressView("Creating link…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 16)

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
                    .padding(12)
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
                .padding(.bottom, 16)

            case .accepting:
                HStack {
                    Spacer()
                    ProgressView("Linking…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 16)

            case .linked:
                VStack(spacing: 12) {
                    Label("Linked successfully", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button(action: {
                        Task { await linkViewModel.unlink() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "link.badge.minus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Unlink")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

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
                .padding(.bottom, 16)

            case .unlinking:
                HStack {
                    Spacer()
                    ProgressView("Unlinking…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 16)

            case .unlinked:
                HStack {
                    Spacer()
                    ProgressView("Preparing link…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
        )
        .onAppear {
            Task {
                await linkViewModel.ensureInviteReady()
            }
        }
    }
}

private func truncatedDisplay(for url: URL) -> String {
    let host = url.host ?? ""
    let path = url.path
    if host.isEmpty && path.isEmpty { return "Invite link" }
    let shortPath = path.isEmpty ? "…" : "/…"
    return host.isEmpty ? "link://\(shortPath)" : "\(host)\(shortPath)"
}
