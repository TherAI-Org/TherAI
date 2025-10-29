import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var tempName: String = ""
    @State private var tempPartner: String = ""

    var body: some View {
        ZStack {
            // Dim the background and block interactions
            Color.black.opacity(0.35).ignoresSafeArea()
                .allowsHitTesting(true)

            VStack(spacing: 16) {
                switch viewModel.step {
                case .none, .asked_name:
                    VStack(spacing: 12) {
                        Text("What's your name?").font(.title2).bold()
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
                            }.buttonStyle(.borderedProminent)
                        }
                    }
                case .asked_partner:
                    VStack(spacing: 12) {
                        Text("What's your partner's name?").font(.title2).bold()
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
                            }.buttonStyle(.borderedProminent)
                        }
                    }
                case .suggested_link:
                    VStack(spacing: 12) {
                        Text("Link with your partner?").font(.title2).bold()
                        Text("You can share an invite to connect accounts for partner messages.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        HStack {
                            Button("Not now") { Task { await viewModel.skipCurrent() } }
                            Spacer()
                            Button("Link now") {
                                // Completing onboarding; UI elsewhere will surface link UI.
                                Task { try? await viewModel.complete(skippedLinkSuggestion: false) }
                            }.buttonStyle(.borderedProminent)
                        }
                    }
                case .completed:
                    VStack { Text("All set!") }
                }
            }
            .padding(20)
            .frame(maxWidth: 420)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
        .task { await viewModel.load() }
    }
}


