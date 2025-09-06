import SwiftUI

struct NotificationsSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Push Notifications")
                                .font(.system(size: 16))
                            Text("Receive push notifications")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(viewModel.settingsData.pushNotifications))
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
        }
    }
}

#Preview {
    NotificationsSettingsView()
}
