import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Inline header with centered title and trailing close button
            ZStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .offset(x: -10)
                    .accessibilityLabel("Close")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            Group {
                ZStack {
                    SettingsBackgroundView()
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Settings Header Card
                            SettingsHeaderView()
                            
                            // Settings Sections
                            ForEach(Array(viewModel.settingsSections.enumerated()), id: \.offset) { sectionIndex, section in
                                SettingsCardView(
                                    section: section,
                                    onToggle: { settingIndex in
                                        viewModel.toggleSetting(for: sectionIndex, settingIndex: settingIndex)
                                    },
                                    onAction: { settingIndex in
                                        viewModel.handleSettingAction(for: sectionIndex, settingIndex: settingIndex)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

struct SettingsHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            // App Icon and Title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 74, height: 74)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 66, height: 66)
                        .overlay(
                            Image(systemName: "gear")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                VStack(spacing: 6) {
                    Text("TherAI Settings")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            
            // Version info
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                
                Text("Version 1.0.0")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.blue.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            Color(.systemBackground).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}

struct SettingsBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemGray6),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(Color.purple.opacity(0.1))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(x: 150, y: 100)
        }
    }
}

#Preview {
    SettingsView()
}
