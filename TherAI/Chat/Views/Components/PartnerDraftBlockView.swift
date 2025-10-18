import SwiftUI
import UIKit
import AVFoundation

struct PartnerDraftBlockView: View {

    enum Action { case send(String) }

    @State private var text: String
    @State private var measuredTextHeight: CGFloat = 0
    @State private var showCheck: Bool = false
    @State private var isSending: Bool = false
    @State private var isConfirmingNormalSend: Bool = false
    @State private var showSentLocally: Bool = false

    let initialText: String
    let isSent: Bool
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

                MessageActionsView(text: text)
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
                // Left-side Cancel (only when confirming)
                if isConfirmingNormalSend {
                    Button(action: {
                        Haptics.impact(.light)
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                            isConfirmingNormalSend = false
                        }
                    }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                // Normal Send (two-step: Send -> Sure? -> Sent)
                HStack(spacing: 8) {
                    Button(action: {
                        // Prevent multiple sends
                        guard !isSent && !isSending else { return }
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        Haptics.impact(.light)

                        if isConfirmingNormalSend {
                            // Second tap confirms send
                            isSending = true
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                // Optimistically show Sent! immediately
                                showSentLocally = true
                                isConfirmingNormalSend = false
                            }
                            onAction(.send(trimmed))
                        } else {
                            // First tap asks for confirmation (animated)
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                isConfirmingNormalSend = true
                            }
                        }
                    }) {
                        ZStack {
                            if (isSent || showSentLocally) {
                                HStack(spacing: 6) {
                                    Text("Sent")
                                        .font(.subheadline)
                                        .foregroundColor(Color.secondary)
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.green)
                                }
                                .transition(.scale.combined(with: .opacity))
                            } else if isConfirmingNormalSend {
                                Text("Sure?")
                                    .font(.subheadline)
                                    .foregroundColor(Color.accentColor)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                HStack(spacing: 6) {
                                    Text("Send")
                                        .font(.subheadline)
                                        .foregroundColor(Color.accentColor)
                                    Image(systemName: "arrow.turn.up.right")
                                        .foregroundColor(Color.accentColor)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .disabled(isSent || isSending)
                }
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
            isConfirmingNormalSend = false
            showSentLocally = false
        }
        .onChange(of: initialText) { _, newValue in
            self.text = newValue
            isConfirmingNormalSend = false
            showSentLocally = false
        }
        .onChange(of: isSent) { _, _ in
            // Reset confirmation state if sent status changes
            isConfirmingNormalSend = false
            // Clear local optimistic flag once parent state reflects sent
            if isSent { showSentLocally = false }
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


