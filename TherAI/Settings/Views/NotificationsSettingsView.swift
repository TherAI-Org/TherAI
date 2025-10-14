import SwiftUI

struct NotificationsSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var pushEnabled: Bool = PushNotificationManager.shared.isPushEnabled

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                            .font(.system(size: 16))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Email Notifications")
                                .font(.system(size: 16))
                            Text("Receive updates via email")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: .constant(viewModel.settingsData.emailNotifications))
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.6))
                            .font(.system(size: 16))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Push Notifications")
                                .font(.system(size: 16, weight: .semibold))
                            Text(pushEnabled ? "Enabled" : "Disabled")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { pushEnabled },
                            set: { newVal in
                                pushEnabled = newVal
                                PushNotificationManager.shared.setPushEnabled(newVal)
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                PushNotificationManager.shared.loadPushEnabledFromDefaults()
                pushEnabled = PushNotificationManager.shared.isPushEnabled
            }
        }
    }
}

#Preview {
    NotificationsSettingsView()
}
