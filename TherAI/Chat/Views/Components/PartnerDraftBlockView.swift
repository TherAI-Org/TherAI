import SwiftUI
import UIKit

struct PartnerDraftBlockView: View {

    enum Action { case send(String) }

    @State private var text: String
    @State private var measuredTextHeight: CGFloat = 0
    @State private var showCheck: Bool = false
    let initialText: String
    @State private var isSending: Bool = false
    let isSent: Bool  // Now passed in from parent instead of local state

    let onAction: (Action) -> Void

    init(initialText: String, isSent: Bool = false, onAction: @escaping (Action) -> Void) {
        self.initialText = initialText
        self.isSent = isSent
        self._text = State(initialValue: initialText)
        self.onAction = onAction
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Message")
                    .font(.footnote)
                    .foregroundColor(Color.secondary)
                    .offset(y: -4)

                Spacer()

                Button(action: {
                    guard !showCheck else { return }
                    UIPasteboard.general.string = text
                    Haptics.impact(.light)
                    showCheck = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCheck = false
                    }
                }) {
                    Image(systemName: showCheck ? "checkmark" : "square.on.square")
                        .font(.system(size: 14))
                        .foregroundColor(Color.secondary)
                }
                .offset(y: -4)
            }

            Divider()
                .padding(.horizontal, -12)
                .offset(y: -4)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .disabled(true)
                    .frame(height: max(40, measuredTextHeight))

                // Invisible sizing text to measure height needed for the editor content
                Text(text.isEmpty ? " " : text)
                    .font(.callout)
                    .foregroundColor(.clear)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HeightReader(height: $measuredTextHeight))
                    .allowsHitTesting(false)
            }

            HStack {
                Spacer()

                Button(action: {
                    // Prevent multiple sends
                    guard !isSent && !isSending else { return }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }

                    Haptics.impact(.light)

                    // Set sending state immediately to prevent double-clicks
                    isSending = true

                    // Call the action (parent will update the sent state)
                    onAction(.send(trimmed))
                }) {
                    HStack(spacing: 6) {
                        Text(isSent ? "Sent" : "Send")
                            .font(.subheadline)
                            .foregroundColor(isSent ? Color.secondary : Color.accentColor)
                            .animation(nil, value: isSent)

                        Group {
                            if isSent {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.green)
                                    .transition(.opacity.combined(with: .scale))
                            } else {
                                Image(systemName: "arrow.turn.up.right")
                                    .foregroundColor(Color.accentColor)
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                    }
                }
                .disabled(isSent || isSending)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground))
                )
        )
        .onAppear {
            if self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.text = self.initialText
            }
        }
        .onChange(of: initialText) { _, newValue in
            self.text = newValue
        }
    }
}

// MARK: - Height measurement helpers

private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HeightReader: View {
    @Binding var height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: ViewHeightKey.self, value: proxy.size.height)
        }
        .onPreferenceChange(ViewHeightKey.self) { newValue in
            if abs(newValue - height) > 0.5 { // avoid tight update loops
                height = newValue
            }
        }
    }
}

#Preview {
    PartnerDraftBlockView(initialText: "Hey love — I've been feeling a bit overwhelmed lately and could use a little extra help this week.", isSent: false) { _ in }
        .padding()
}


