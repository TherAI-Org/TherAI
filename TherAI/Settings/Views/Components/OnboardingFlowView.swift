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
                VStack(spacing: 14) {
                    Text("Almost there 🎯")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Share your invite to connect with your partner")
                        .font(.title2).bold()
                        .multilineTextAlignment(.center)

                    // Reuse the existing share UI from the app
                    PartnerInviteBannerView()
                        .environmentObject(linkVM)
                        .onAppear { Task { await linkVM.ensureInviteReady() } }

                    HStack {
                        Button("Not now") { Task { try? await viewModel.complete(skippedLinkSuggestion: true) } }
                        Spacer()
                        Button("Finish") { Task { try? await viewModel.complete(skippedLinkSuggestion: false) } }
                            .buttonStyle(.borderedProminent)
                    }
                }
            case .completed:
                VStack { Text("All set!") }
            }
        }
    }
}


