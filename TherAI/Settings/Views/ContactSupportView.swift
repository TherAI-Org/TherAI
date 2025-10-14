import SwiftUI

struct ContactSupportView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("If you have any questions, feel free to reach out to:")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)

            Text("📧  sgzrov@gmail.com")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.primary)

            Text("📧  muhammad84044@gmail.com")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(20)
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContactSupportView()
}


