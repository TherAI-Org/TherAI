import SwiftUI

private struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ViewportHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MessagesListView: View {
    let messages: [ChatMessage]
    let isInputFocused: Bool
    let onBackgroundTap: () -> Void

    @State private var scrollPositionId: UUID? = nil
    @State private var isUserScrolling: Bool = false
    @State private var isAtBottom: Bool = true
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    private var lastMessageId: UUID? { messages.last?.id }
    private var shouldAnchorBottom: Bool { contentHeight > viewportHeight }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                        .id(message.id)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { onBackgroundTap() }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ViewportHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .defaultScrollAnchor(shouldAnchorBottom ? .bottom : .top)
        .scrollPosition(id: $scrollPositionId, anchor: shouldAnchorBottom ? .bottom : .top)
        .onPreferenceChange(ViewportHeightPreferenceKey.self) { viewportHeight = $0 }
        .onPreferenceChange(ContentHeightPreferenceKey.self) { contentHeight = $0 }
        .onChange(of: viewportHeight) { _, _ in
            if shouldAnchorBottom && !isUserScrolling && isAtBottom {
                withAnimation(.easeOut(duration: 0.2)) { scrollPositionId = lastMessageId }
            }
        }
        .onAppear {
            if shouldAnchorBottom { scrollPositionId = lastMessageId } else { scrollPositionId = nil }
            isAtBottom = !shouldAnchorBottom || (scrollPositionId == lastMessageId)
        }
        .onChange(of: messages.count) { _, _ in
            if shouldAnchorBottom && isAtBottom {
                withAnimation(.easeOut(duration: 0.2)) { scrollPositionId = lastMessageId }
            }
        }
        .onChange(of: shouldAnchorBottom) { _, newValue in
            if newValue && isAtBottom {
                withAnimation(.easeOut(duration: 0.2)) { scrollPositionId = lastMessageId }
            }
        }
        .onScrollPhaseChange { _, phase in
            if phase == .idle {
                withAnimation(.easeOut(duration: 0.2)) { isUserScrolling = false }
            } else {
                withAnimation(.easeIn(duration: 0.1)) { isUserScrolling = true }
            }
        }
        .onChange(of: scrollPositionId) { _, _ in
            if shouldAnchorBottom {
                isAtBottom = (scrollPositionId == lastMessageId)
            } else {
                isAtBottom = true
            }
        }
        .onChange(of: isInputFocused) { _, _ in
            if shouldAnchorBottom && isAtBottom {
                withAnimation(.easeOut(duration: 0.2)) { scrollPositionId = lastMessageId }
            }
        }
        .overlay(alignment: .trailing) {
            Capsule()
                .fill(Color.secondary.opacity(0.6))
                .frame(width: 2, height: 22)
                .opacity(isUserScrolling ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: isUserScrolling)
                .padding(.trailing, 4)
                .padding(.vertical, 12)
        }
        .scrollBounceBehavior(shouldAnchorBottom ? .basedOnSize : .always)
        .scrollIndicators(.hidden)
    }
}


