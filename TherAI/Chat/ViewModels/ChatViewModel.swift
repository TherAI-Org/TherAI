import Foundation
import SwiftUI
import Supabase

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""

    private let backend = BackendService.shared
    private let authService = AuthService.shared

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(content: inputText, isFromUser: true)
        messages.append(userMessage)

        inputText = ""  // Clear input text

        Task {
            do {
                let session = try await authService.client.auth.session
                let accessToken = session.accessToken

                let responseText = try await backend.sendChatMessage(userMessage.content, accessToken: accessToken)
                let aiMessage = ChatMessage(content: responseText, isFromUser: false)
                await MainActor.run {
                    self.messages.append(aiMessage)
                }
            } catch {
                let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", isFromUser: false)
                await MainActor.run {
                    self.messages.append(errorMessage)
                }
            }
        }
    }

    func clearChat() {
        messages.removeAll()
    }
}

