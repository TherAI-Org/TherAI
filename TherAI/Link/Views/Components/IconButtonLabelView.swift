import SwiftUI

struct IconButtonLabelView: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(Color(.systemGray6))
                    .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
            )
    }
}


