import Foundation
import SwiftUI
import Supabase

final class OnboardingViewModel: ObservableObject {
    enum Step: String { case none, asked_name, asked_partner, suggested_link, completed }

    @Published var isLoading: Bool = false
    @Published var fullName: String = ""
    @Published var partnerName: String = ""
    @Published var step: Step = .none
    @Published var isLinked: Bool = false
    @Published var errorMessage: String? = nil

    func load() async {
        guard let token = try? await AuthService.shared.client.auth.session.accessToken else { return }
        await MainActor.run { self.isLoading = true }
        do {
            let info = try await BackendService.shared.fetchOnboarding(accessToken: token)
            await MainActor.run {
                self.fullName = info.full_name
                self.partnerName = info.partner_display_name ?? ""
                let fetchedStep = Step(rawValue: info.onboarding_step) ?? .none
                self.isLinked = info.linked
                // If the user is linked via invite, auto-complete onboarding and persist it
                if info.linked && fetchedStep != .completed {
                    self.step = .completed
                    Task { _ = try? await BackendService.shared.updateOnboarding(accessToken: token, update: .init(partner_display_name: nil, onboarding_step: Step.completed.rawValue)) }
                } else {
                    self.step = fetchedStep
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }

    func setFullName(_ name: String?) async {
        guard let token = try? await AuthService.shared.client.auth.session.accessToken else { return }
        do {
            let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                await MainActor.run { self.errorMessage = "Please enter your name or tap Skip." }
                return
            }
            // Optimistically update UI and advance immediately
            await MainActor.run {
                self.fullName = trimmed
                self.errorMessage = nil
                self.step = .asked_partner
            }
            // Persist in background; do not block UI flow
            Task { _ = try? await BackendService.shared.updateProfile(accessToken: token, fullName: trimmed, bio: nil) }
            Task { try? await self.advance(to: .asked_partner) }
        } catch { }
    }

    func setPartnerName(_ name: String?) async {
        guard let token = try? await AuthService.shared.client.auth.session.accessToken else { return }
        do {
            let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                await MainActor.run { self.errorMessage = "Please enter partner name or tap Skip." }
                return
            }
            // Optimistically advance and store locally
            await MainActor.run {
                self.partnerName = trimmed
                self.errorMessage = nil
                self.step = .suggested_link
            }
            // Persist via onboarding endpoint so fetchOnboarding reflects the change
            Task {
                do {
                    _ = try await BackendService.shared.updateOnboarding(
                        accessToken: token,
                        update: .init(partner_display_name: trimmed, onboarding_step: Step.suggested_link.rawValue)
                    )
                } catch {
                    // Fallback: try profile update for partner name; keep UI advanced
                    _ = try? await BackendService.shared.updateProfile(accessToken: token, fullName: nil, bio: nil, partnerDisplayName: trimmed)
                    await MainActor.run { self.errorMessage = nil }
                }
            }
        } catch { }
    }

    func skipCurrent() async {
        guard let token = try? await AuthService.shared.client.auth.session.accessToken else { return }
        switch step {
        case .none, .asked_name:
            // Do not persist anything on Skip; just advance the step
            Task { _ = try? await BackendService.shared.updateOnboarding(accessToken: token, update: .init(partner_display_name: nil, onboarding_step: Step.asked_partner.rawValue)) }
            await MainActor.run { self.step = .asked_partner; self.errorMessage = nil }

        case .asked_partner:
            // Do not persist anything on Skip; just advance the step
            Task { _ = try? await BackendService.shared.updateOnboarding(accessToken: token, update: .init(partner_display_name: nil, onboarding_step: Step.suggested_link.rawValue)) }
            await MainActor.run { self.step = .suggested_link; self.errorMessage = nil }

        case .suggested_link:
            try? await complete(skippedLinkSuggestion: true)

        case .completed:
            break
        }
    }

    func complete(skippedLinkSuggestion: Bool = false) async throws {
        guard let token = try? await AuthService.shared.client.auth.session.accessToken else { return }
        do {
            _ = try await BackendService.shared.updateOnboarding(accessToken: token, update: .init(partner_display_name: nil, onboarding_step: Step.completed.rawValue))
            await MainActor.run { self.step = .completed }
        } catch {
            // Try alternate base path/methods via a profile update (no-op, just to test connectivity)
            _ = try? await BackendService.shared.updateProfile(accessToken: token, fullName: nil, bio: nil)
            await MainActor.run { self.step = .completed }
        }
    }

    private func advance(to newStep: Step) async throws {
        guard let token = try? await AuthService.shared.client.auth.session.accessToken else { return }
        _ = try await BackendService.shared.updateOnboarding(accessToken: token, update: .init(partner_display_name: nil, onboarding_step: newStep.rawValue))
        await MainActor.run { self.step = newStep }
    }
}


