import SwiftUI

struct IconButtonLabelView: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.primary)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(Color(.systemBackground))
                    .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
            )
    }
}


