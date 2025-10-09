import SwiftUI

struct PersonalizationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var relationshipStatus: String = ""
    @State private var aboutYou: String = ""
    @State private var customInstructions: String = ""
    @State private var therapistStyle: String = "Default"
    @State private var isCustomizationEnabled: Bool = true
    @State private var partnerName: String = ""
    @State private var focusAreas: Set<String> = []
    @FocusState private var focusedField: Field?
    @State private var keyboardHeight: CGFloat = 0

    private let styleOptions = ["Default", "Supportive", "Direct", "Empathetic", "Reflective"]
    private let focusOptions = ["Communication", "Trust", "Conflict", "Intimacy"]

    private func styleSubtitle(for option: String) -> String {
        switch option {
        case "Default": return "Balanced and adaptive"
        case "Supportive": return "Warm and encouraging"
        case "Direct": return "Clear and to the point"
        case "Empathetic": return "Validating and gentle"
        case "Reflective": return "Thoughtful and exploratory"
        default: return ""
        }
    }

    private func capsuleBackground(cornerRadius: CGFloat = 22) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private enum Field: Hashable { case name, relationship, partner, instructions, about }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    // Enable customization toggle (white capsule)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Enable customization")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            Toggle("", isOn: $isCustomizationEnabled)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(capsuleBackground())

                        Text("Customize how TherAI responds to you")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 16)

                    // Content that gets disabled/tinted when customization is off
                    VStack(spacing: 20) {
                        // Therapist style (capsule with left label and right value)
                        VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("TherAI style")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            Menu {
                                ForEach(styleOptions, id: \.self) { option in
                                    Button(action: { therapistStyle = option }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(option)
                                                Text(styleSubtitle(for: option))
                                                    .font(.footnote)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            if option == therapistStyle { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(therapistStyle)
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(capsuleBackground())
                        
                        Text("Set the style and tone TherAI uses when responding")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)

                    

                    // Custom instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CUSTOM INSTRUCTIONS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        ZStack(alignment: .topLeading) {
                            capsuleBackground()
                                .frame(minHeight: 100)
                            
                            if customInstructions.isEmpty {
                                Text("Describe or select traits")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                            
                            TextEditor(text: $customInstructions)
                                .font(.system(size: 16))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.clear)
                                .frame(minHeight: 100)
                                .focused($focusedField, equals: .instructions)
                                .id(Field.instructions)
                        }
                        
                        // Focus areas (compact chips)
                        HStack(spacing: 8) {
                            ForEach(focusOptions, id: \.self) { option in
                                let selected = focusAreas.contains(option)
                                Button(action: {
                                    if selected { focusAreas.remove(option) } else { focusAreas.insert(option) }
                                }) {
                                    Text(option)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selected ? .white : Color(red: 0.4, green: 0.2, blue: 0.6))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Group {
                                                if selected {
                                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                        .fill(Color(red: 0.4, green: 0.2, blue: 0.6))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                        .fill(Color.white)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                                        )
                                                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                                                }
                                            }
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Your name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR NAME")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        TextField("Name", text: $name)
                            .font(.system(size: 16))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(capsuleBackground())
                            .focused($focusedField, equals: .name)
                            .id(Field.name)
                    }
                    .padding(.horizontal, 16)

                    // Relationship status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RELATIONSHIP STATUS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        TextField("Dating, married, single, etc.", text: $relationshipStatus)
                            .font(.system(size: 16))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(capsuleBackground())
                            .focused($focusedField, equals: .relationship)
                            .id(Field.relationship)
                    }
                    .padding(.horizontal, 16)

                    // Partner name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PARTNER NAME")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        TextField("I'll address them by this name", text: $partnerName)
                            .font(.system(size: 16))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(capsuleBackground())
                            .focused($focusedField, equals: .partner)
                            .id(Field.partner)
                    }
                    .padding(.horizontal, 16)

                    // More about you
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MORE ABOUT YOU")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        ZStack(alignment: .topLeading) {
                            capsuleBackground()
                                .frame(minHeight: 80)
                            
                            if aboutYou.isEmpty {
                                Text("Interests, values, or preferences to keep in mind...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                            
                            TextEditor(text: $aboutYou)
                                .font(.system(size: 16))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color.clear)
                                .frame(minHeight: 80)
                                .focused($focusedField, equals: .about)
                                .id(Field.about)
                        }
                    }
                    .padding(.horizontal, 16)
                    }
                    .opacity(isCustomizationEnabled ? 1.0 : 0.45)
                    .disabled(!isCustomizationEnabled)

                    Spacer(minLength: 24)
                }
                .padding(.vertical, 16)
                .padding(.bottom, keyboardHeight)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                    dismissKeyboard()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedField) { field in
                if let f = field {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(f, anchor: .center)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                guard let info = notification.userInfo,
                      let frame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) else { return }
                let height = max(0, UIScreen.main.bounds.height - frame.origin.y)
                withAnimation(.easeInOut(duration: 0.2)) { keyboardHeight = height }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { keyboardHeight = 0 }
            }
            }
            .navigationTitle("Personalization")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save personalization data
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    PersonalizationView()
}
#endif