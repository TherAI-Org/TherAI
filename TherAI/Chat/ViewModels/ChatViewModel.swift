import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""

    // Hardcoded response message
    private let hardcodedResponse = "Hello! I'm your AI assistant. How can I help you today?"

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(content: inputText, isFromUser: true)
        messages.append(userMessage)

        // Clear input
        inputText = ""

        // Simulate AI response delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let aiMessage = ChatMessage(content: self.hardcodedResponse, isFromUser: false)
            self.messages.append(aiMessage)
        }
    }

    func clearChat() {
        messages.removeAll()
    }
}

