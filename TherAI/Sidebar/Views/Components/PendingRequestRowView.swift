import SwiftUI

struct PendingRequestRowView: View {

    let request: DialogueViewModel.DialogueRequest

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Partner Request")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                Text(request.requestContent)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}


