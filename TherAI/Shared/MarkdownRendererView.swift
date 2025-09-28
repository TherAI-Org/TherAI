import SwiftUI

// Lightweight Markdown renderer tuned for chat content
// Supports: headings (#, ##, ###), ordered and unordered lists, paragraphs, and horizontal rules (---, ***, ___)
// Inline styling (bold/italic/emoji/links) is applied via AttributedString inline parsing
struct MarkdownRendererView: View {
    let markdown: String

    private enum Block: Equatable {
        case heading(level: Int, text: String)
        case unorderedList(items: [String])
        case orderedList(items: [String])
        case paragraph(String)
        case rule
        case quote(String)
    }

    private struct BlockItem: Identifiable, Equatable {
        let id = UUID()
        let block: Block
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(parse(markdown)) { item in
                switch item.block {
                case .heading(let level, let text):
                    headingView(level: level, text: text)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                case .unorderedList(let items):
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.0) { _, raw in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("•")
                                    .font(.system(size: 16, weight: .bold))
                                inlineText(raw)
                            }
                        }
                    }
                case .orderedList(let items):
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.0) { idx, raw in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text("\(idx + 1).")
                                        .font(.system(size: 16, weight: .semibold))
                                    inlineText(raw)
                                }
                                if idx < items.count - 1 {
                                    Divider()
                                        .overlay(Color.secondary.opacity(0.12))
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                case .paragraph(let text):
                    inlineText(text)
                case .quote(let text):
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 3)
                            .cornerRadius(1.5)
                        inlineText(text)
                    }
                case .rule:
                    Divider()
                        .overlay(Color.secondary.opacity(0.08))
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headingView(level: Int, text: String) -> some View {
        let attributed = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
        let base: Text = attributed.map(Text.init) ?? Text(text)
        switch level {
        case 1:
            return AnyView(base.font(Typography.title))
        case 2:
            return AnyView(base.font(Typography.title2))
        default:
            return AnyView(base.font(Typography.body.weight(.semibold)))
        }
    }

    private func inlineText(_ text: String) -> Text {
        let transformed = applyInlineTypography(to: text)
        if let attributed = try? AttributedString(markdown: transformed, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed).font(Typography.body)
        } else {
            return Text(transformed).font(Typography.body)
        }
    }

    private func applyInlineTypography(to input: String) -> String {
        var s = input
        // Replace simple arrows and spaced em-dash without overstepping normal hyphens
        s = s.replacingOccurrences(of: "->", with: "→")
        s = s.replacingOccurrences(of: "<-", with: "←")
        s = s.replacingOccurrences(of: " -- ", with: " — ")
        return s
    }

    // MARK: - Parser
    private func parse(_ input: String) -> [BlockItem] {
        let lines = input.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).map { String($0) }
        var items: [BlockItem] = []

        var paragraphBuffer: [String] = []
        var ulBuffer: [String] = []
        var olBuffer: [String] = []
        var quoteBuffer: [String] = []

        func flushParagraph() {
            if !paragraphBuffer.isEmpty {
                let text = paragraphBuffer.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                items.append(BlockItem(block: .paragraph(text)))
                paragraphBuffer.removeAll()
            }
        }
        func flushUL() {
            if !ulBuffer.isEmpty {
                items.append(BlockItem(block: .unorderedList(items: ulBuffer)))
                ulBuffer.removeAll()
            }
        }
        func flushOL() {
            if !olBuffer.isEmpty {
                items.append(BlockItem(block: .orderedList(items: olBuffer)))
                olBuffer.removeAll()
            }
        }
        func flushQuote() {
            if !quoteBuffer.isEmpty {
                let text = quoteBuffer.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                items.append(BlockItem(block: .quote(text)))
                quoteBuffer.removeAll()
            }
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: CharacterSet.whitespaces)
            if line.isEmpty {
                flushParagraph(); flushUL(); flushOL(); flushQuote()
                continue
            }

            // Horizontal rule
            if line == "---" || line == "***" || line == "___" {
                flushParagraph(); flushUL(); flushOL(); flushQuote()
                items.append(BlockItem(block: .rule))
                continue
            }

            // Heading
            if line.hasPrefix("#") {
                let hashes = line.prefix { $0 == "#" }
                let after = line.dropFirst(hashes.count).trimmingCharacters(in: CharacterSet.whitespaces)
                let level = min(max(hashes.count, 1), 3) // limit to H1–H3 in chat
                flushParagraph(); flushUL(); flushOL(); flushQuote()
                items.append(BlockItem(block: .heading(level: level, text: String(after))))
                continue
            }

            // Blockquote: lines starting with "> "
            if let range = line.range(of: "^>\\s+", options: String.CompareOptions.regularExpression) {
                flushParagraph(); flushUL(); flushOL()
                let content = String(line[range.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)
                quoteBuffer.append(content)
                continue
            }

            // Ordered list: "1. Item"
            if let range = line.range(of: "^\\d+\\.\\s+", options: String.CompareOptions.regularExpression) {
                flushParagraph(); flushUL(); flushQuote()
                let item = String(line[range.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)
                olBuffer.append(item)
                continue
            }

            // Unordered list: "- ", "* ", "+ "
            if let range = line.range(of: "^[-*+]\\s+", options: String.CompareOptions.regularExpression) {
                flushParagraph(); flushOL(); flushQuote()
                let item = String(line[range.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)
                ulBuffer.append(item)
                continue
            }

            // Default: paragraph line (preserve sentence spacing)
            if !quoteBuffer.isEmpty { flushQuote() }
            paragraphBuffer.append(line)
        }

        // Flush any remaining buffers
        flushParagraph(); flushUL(); flushOL(); flushQuote()
        return items
    }
}


