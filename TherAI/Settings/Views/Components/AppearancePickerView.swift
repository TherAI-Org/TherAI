import SwiftUI

enum AppearanceOption: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }
}

struct AppearancePickerView: View {
    let current: AppearanceOption
    let onSelect: (AppearanceOption) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppearanceOption.allCases) { option in
                    Button(action: { onSelect(option) }) {
                        HStack {
                            Text(option.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if option == current {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AppearancePickerView(current: .system, onSelect: { _ in })
}


