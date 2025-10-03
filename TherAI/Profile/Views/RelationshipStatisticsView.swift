import SwiftUI

struct RelationshipStatisticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var statsVM: ProfileViewModel

    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
            }

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .light ? Color.white : Color(.systemGray6))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }

    private func colorFor(_ key: String, value: String?) -> Color {
        let v = (value ?? "").lowercased()
        switch key {
        case "communication":
            if v.contains("excellent") || v.contains("great") { return .green }
            if v.contains("good") { return .blue }
            if v.contains("fair") { return .orange }
            if v.contains("poor") { return .red }
            return Color(.systemGray)
        case "trust":
            if v.contains("very strong") || v.contains("strong") { return .green }
            if v.contains("moderate") { return .orange }
            if v.contains("low") { return .red }
            return Color(.systemGray)
        case "goals":
            if v.contains("aligned") { return Color.purple }
            if v.contains("partial") { return Color.indigo }
            if v.contains("divergent") { return .orange }
            return Color(.systemGray)
        case "intimacy":
            if v.contains("deep") { return .pink }
            if v.contains("warm") { return .orange }
            if v.contains("cool") { return Color(.systemGray) }
            return Color(.systemGray)
        default:
            return Color(.systemGray)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Statistics")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { Task { await statsVM.fetchRelationshipStats(force: true) } }) {
                    ZStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .opacity(statsVM.isFetchingStats ? 0 : 1)
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.9)
                            .opacity(statsVM.isFetchingStats ? 1 : 0)
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                    .opacity(0.9)
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statTile(title: "Communication", value: (statsVM.statCommunication?.isEmpty == false ? statsVM.statCommunication! : "—"), icon: "message.fill", color: colorFor("communication", value: statsVM.statCommunication))

                statTile(title: "Trust Level", value: (statsVM.statTrustLevel?.isEmpty == false ? statsVM.statTrustLevel! : "—"), icon: "lock.shield.fill", color: colorFor("trust", value: statsVM.statTrustLevel))

                statTile(title: "Future Goals", value: (statsVM.statFutureGoals?.isEmpty == false ? statsVM.statFutureGoals! : "—"), icon: "target", color: colorFor("goals", value: statsVM.statFutureGoals))

                statTile(title: "Intimacy", value: (statsVM.statIntimacy?.isEmpty == false ? statsVM.statIntimacy! : "—"), icon: "heart.fill", color: colorFor("intimacy", value: statsVM.statIntimacy))
            }
            .padding(.bottom, 16)
        }
    }
}


#Preview {
    RelationshipStatisticsView()
        .padding(20)
}


