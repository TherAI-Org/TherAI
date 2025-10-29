import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var linkVM: LinkViewModel

    @State private var tempName: String = ""
    @State private var tempPartner: String = ""
    @State private var lastStepIndex: Int = 0

    private func stepIndex(_ s: OnboardingViewModel.Step) -> Int {
        switch s { case .none: return 0; case .asked_name: return 1; case .asked_partner: return 2; case .suggested_link: return 3; case .completed: return 4 }
    }

    var body: some View {
        ZStack {
            // Dim the background and block interactions
            LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            // Card container with animated step transitions
            ZStack {
                cardView
                    .id(viewModel.step)
                    .transition(currentTransition)
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.9), value: viewModel.step)
            .padding(20)
            .frame(maxWidth: 460)
            .background(
                LinearGradient(colors: [Color.white, Color.white.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 24)
        }
        .onChange(of: viewModel.step) { new in
            lastStepIndex = stepIndex(new)
        }
    }

    private var currentTransition: AnyTransition {
        let current = stepIndex(viewModel.step)
        let forward = current >= lastStepIndex
        let insertion = AnyTransition.move(edge: forward ? .trailing : .leading).combined(with: .opacity)
        let removal = AnyTransition.move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    @ViewBuilder
    private var cardView: some View {
        VStack(spacing: 16) {
            switch viewModel.step {
            case .none, .asked_name:
                VStack(spacing: 14) {
                    Text("Welcome 👋")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("What's your name?")
                        .font(.title2).bold()
                    TextField("Your name", text: $tempName)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { tempName = viewModel.fullName }
                    if let err = viewModel.errorMessage, !err.isEmpty {
                        Text(err).font(.footnote).foregroundColor(.red)
                    }
                    HStack {
                        Button("Skip") { Task { await viewModel.skipCurrent() } }
                        Spacer()
                        Button("Continue") {
                            let value = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task { await viewModel.setFullName(value.isEmpty ? nil : value) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            case .asked_partner:
                VStack(spacing: 14) {
                    Text("Nice to meet you ✨")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("What's your partner's name?")
                        .font(.title2).bold()
                    TextField("Partner name", text: $tempPartner)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { tempPartner = viewModel.partnerName }
                    if let err = viewModel.errorMessage, !err.isEmpty {
                        Text(err).font(.footnote).foregroundColor(.red)
                    }
                    HStack {
                        Button("Skip") { Task { await viewModel.skipCurrent() } }
                        Spacer()
                        Button("Continue") {
                            let value = tempPartner.trimmingCharacters(in: .whitespacesAndNewlines)
                            Task { await viewModel.setPartnerName(value.isEmpty ? nil : value) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            case .suggested_link:
                VStack(spacing: 16) {
                    Text("Share this link to connect with your partner")
                        .font(.title2).bold()
                        .multilineTextAlignment(.center)

                    Group {
                        switch linkVM.state {
                        case .creating:
                            HStack { Spacer(); ProgressView("Preparing link…"); Spacer() }
                                .padding(12)
                        case .shareReady(let url):
                            HStack(spacing: 10) {
                                Image(systemName: "link")
                                    .foregroundColor(.primary)
                                Text(truncatedDisplay(for: url))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                ShareLink(item: url) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                                .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                                        )
                                }
                            }
                            .padding(12)
                        case .linked:
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("You're linked")
                                Spacer()
                            }.padding(12)
                        case .accepting, .unlinking:
                            HStack { Spacer(); ProgressView("Working…"); Spacer() }.padding(12)
                        case .idle, .unlinked, .error:
                            HStack { Spacer(); Button("Generate link") { Task { await linkVM.ensureInviteReady() } }.buttonStyle(.borderedProminent); Spacer() }.padding(4)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    )

                    HStack {
                        Spacer()
                        Button("Complete") { Task { try? await viewModel.complete(skippedLinkSuggestion: false) } }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .onAppear { Task { await linkVM.ensureInviteReady() } }
            case .completed:
                VStack { Text("All set!") }
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
}


