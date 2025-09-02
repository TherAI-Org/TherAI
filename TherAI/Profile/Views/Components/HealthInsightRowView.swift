import SwiftUI

struct HealthInsightRowView: View {
    let title: String
    let value: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer()

                    Text(value)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        )
    }
}


#Preview {
    VStack(spacing: 12) {
        HealthInsightRowView(
            title: "Communication Score",
            value: "9.2/10",
            description: "Excellent verbal and non-verbal communication patterns",
            color: .blue
        )
        HealthInsightRowView(
            title: "Active Listening",
            value: "High",
            description: "Consistent reflection and validation",
            color: .green
        )
    }
    .padding(20)
}


