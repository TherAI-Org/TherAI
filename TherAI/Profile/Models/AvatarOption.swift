import Foundation
import SwiftUI

struct AvatarOption: Identifiable, Equatable {
    let id: Int
    let emoji: String
}

extension AvatarOption {
    static func defaultOptions() -> [AvatarOption] {
        let emojis = ["🐱","🐶","🐰","🐼","🐨","🦊","🐯","🦁"]
        return emojis.enumerated().map { AvatarOption(id: $0.offset, emoji: $0.element) }
    }

    static let colors: [Color] = [
        .blue, .pink, .purple, .orange, .green, .red, .yellow, .teal
    ]

    static func color(for id: Int) -> Color {
        let index = id % max(colors.count, 1)
        return colors[index]
    }
}



