import Foundation
import SwiftUI

final class LinkViewModel: ObservableObject {

    enum LinkingState: Equatable {
        case idle
        case creating
        case shareReady(url: URL)
        case accepting
        case linked
        case unlinking
        case unlinked
        case error(message: String)
    }

    @Published private(set) var state: LinkingState = .idle
    @Published var pendingInviteToken: String? = nil
    @Published private(set) var linkedAt: Date? = nil

    private var accessTokenProvider: () async throws -> String

    init(accessTokenProvider: @escaping () async throws -> String) {
        self.accessTokenProvider = accessTokenProvider
    }

    @MainActor
    func createInviteLink() async {
        state = .creating
        do {
            let token = try await accessTokenProvider()
            let url = try await BackendService.shared.createLinkInvite(accessToken: token)
            state = .shareReady(url: url)
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    @MainActor
    func acceptInvite(using inviteToken: String) async {
        state = .accepting
        do {
            let token = try await accessTokenProvider()
            try await BackendService.shared.acceptLinkInvite(inviteToken: inviteToken, accessToken: token)
            try await refreshStatus()
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    @MainActor
    func unlink() async {
        state = .unlinking
        do {
            let token = try await accessTokenProvider()
            _ = try await BackendService.shared.unlink(accessToken: token)
            await createInviteLink()
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    @MainActor
    func refreshStatus() async throws {
        let token = try await accessTokenProvider()
        let status = try await BackendService.shared.fetchLinkStatus(accessToken: token)
        linkedAt = status.linkedAt
        state = status.linked ? .linked : .idle
    }

    @MainActor
    func ensureInviteReady() async {
        do { try await refreshStatus() } catch {}
        switch state {
        case .linked, .shareReady:
            return
        case .creating, .accepting, .unlinking:
            return
        case .idle, .unlinked, .error:
            await createInviteLink()
        }
    }

    func captureIncomingInviteToken(_ token: String) {
        pendingInviteToken = token
    }
}

#if DEBUG
extension LinkViewModel {
    static func preview(state: LinkingState) -> LinkViewModel {
        let viewModel = LinkViewModel(accessTokenProvider: { "" })
        viewModel.state = state
        return viewModel
    }
}
#endif


