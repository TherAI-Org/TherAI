import Foundation
import SwiftUI

@MainActor
final class SessionsViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false

    private let backend = BackendService.shared
    private let authService = AuthService.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await authService.client.auth.session
            let accessToken = session.accessToken
            let dtos = try await backend.fetchSessions(accessToken: accessToken)
            self.sessions = dtos.map(ChatSession.init(dto:))
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
}


