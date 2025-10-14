import SwiftUI
import UIKit

struct PartnerMessageBlockView: View {

    let text: String

    @State private var showCheck: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Partner")
                    .font(.footnote)
                    .foregroundColor(Color.secondary)
                    .offset(y: -4)

                Spacer()

                Button(action: {
                    guard !showCheck else { return }
                    UIPasteboard.general.string = text
                    Haptics.impact(.light)
                    showCheck = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCheck = false
                    }
                }) {
                    Image(systemName: showCheck ? "checkmark" : "square.on.square")
                        .font(.system(size: 14))
                        .foregroundColor(Color.secondary)
                }
                .offset(y: -4)
            }

            Divider()
                .padding(.horizontal, -12)
                .offset(y: -4)

            Text(text.isEmpty ? " " : text)
                .font(.callout)
                .foregroundColor(.primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground))
                )
        )
    }
}


