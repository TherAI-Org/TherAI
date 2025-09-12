import SwiftUI

struct RelationshipInsightsSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Relationship Insights")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                RelationshipStatisticsView(
                    title: "Communication",
                    value: "Great",
                    icon: "message.fill",
                    color: Color(red: 0.26, green: 0.58, blue: 1.00)
                )

                RelationshipStatisticsView(
                    title: "Trust Level",
                    value: "Strong",
                    icon: "lock.shield.fill",
                    color: Color.green
                )

                RelationshipStatisticsView(
                    title: "Future Goals",
                    value: "Aligned",
                    icon: "target",
                    color: Color(red: 0.63, green: 0.32, blue: 0.98)
                )

                RelationshipStatisticsView(
                    title: "Intimacy",
                    value: "Deep",
                    icon: "heart.fill",
                    color: Color.pink
                )
            }
        }
    }
}


#Preview {
    RelationshipInsightsSectionView()
        .padding(20)
}


