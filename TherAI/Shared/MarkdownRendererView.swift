import SwiftUI

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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(parse(markdown)) { item in
                switch item.block {
                case .heading(_, let text):
                    Group {
                        if let attributed = try? AttributedString(
                            markdown: text,
                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                        ) {
                            Text(attributed)
                        } else {
                            Text(text)
                        }
                    }
                    .font(.system(size: 21, weight: .semibold))
                    .padding(.top, 16)
                    .padding(.bottom, 18)
                case .unorderedList(let items):
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(items.enumerated()), id: \.0) { _, raw in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                    .font(.system(size: 12, weight: .bold))
                                    .baselineOffset(2)
                                inlineText(raw)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .padding(.vertical, 18)
                case .orderedList(let items):
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.0) { idx, raw in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(idx + 1).")
                                    .font(.system(size: 17, weight: .semibold))
                                inlineText(raw)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.vertical, 18)
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
                        .overlay(Color.secondary.opacity(0.02))
                        .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineText(_ text: String) -> some View {
        let transformed = applyInlineTypography(to: text)
        if let attributed = try? AttributedString(markdown: transformed, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
                .font(.system(size: 17, weight: .regular))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        } else {
            return Text(transformed)
                .font(.system(size: 17, weight: .regular))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
        }
    }

    private func applyInlineTypography(to input: String) -> String {
        var s = input
        s = s.replacingOccurrences(of: "->", with: " → ")
        s = s.replacingOccurrences(of: "<-", with: " ← ")
        // Normalize common hyphen patterns to em‑dash for readability
        s = s.replacingOccurrences(of: " --- ", with: " — ")
        s = s.replacingOccurrences(of: " -- ", with: " — ")
        s = s.replacingOccurrences(of: " - ", with: " — ")
        // Ensure spacing around em‑dash and arrows
        s = s.replacingOccurrences(of: "—", with: " — ")
        s = s.replacingOccurrences(of: "→", with: " → ")
        s = s.replacingOccurrences(of: "←", with: " ← ")
        // Collapse duplicate spaces introduced by replacements
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s
    }

    private func parse(_ input: String) -> [BlockItem] {
        let lines = input.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).map { String($0) }
        var items: [BlockItem] = []

        var paragraphBuffer: [String] = []
        var ulBuffer: [String] = []
        var olBuffer: [String] = []
        var quoteBuffer: [String] = []
        // Note: we intentionally allow ordered lists to continue across single blank lines

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

        var idx = 0
        while idx < lines.count {
            let raw = lines[idx]
            let line = raw.trimmingCharacters(in: CharacterSet.whitespaces)

            if line.isEmpty {
                // Do not flush ordered list on a blank line; allow continued numbering across soft breaks
                flushParagraph(); flushUL(); flushQuote()
                idx += 1
                continue
            }

            let isOrdered = line.range(of: "^\\d+\\.\\s+", options: .regularExpression) != nil
            if !olBuffer.isEmpty && !isOrdered {
                // We were in an ordered list and now a non-ordered line begins → close the list
                flushOL()
            }

            if line == "---" || line == "***" || line == "___" {
                flushParagraph(); flushUL(); flushOL(); flushQuote()
                items.append(BlockItem(block: .rule))
                idx += 1
                continue
            }

            if line.hasPrefix("#") {
                let hashes = line.prefix { $0 == "#" }
                let after = line.dropFirst(hashes.count).trimmingCharacters(in: CharacterSet.whitespaces)
                let level = min(max(hashes.count, 1), 3)
                flushParagraph(); flushUL(); flushOL(); flushQuote()
                items.append(BlockItem(block: .heading(level: level, text: String(after))))
                idx += 1
                continue
            }

            if let range = line.range(of: "^>\\s+", options: .regularExpression) {
                flushParagraph(); flushUL(); flushOL()
                let content = String(line[range.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)
                quoteBuffer.append(content)
                idx += 1
                continue
            }

            if let range = line.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                // Continue same ordered list across single blank lines
                flushParagraph(); flushUL(); flushQuote()
                let item = String(line[range.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)
                olBuffer.append(item)
                idx += 1
                continue
            }

            if let range = line.range(of: "^[-*+]\\s+", options: .regularExpression) {
                flushParagraph(); flushOL(); flushQuote()
                let item = String(line[range.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)
                ulBuffer.append(item)
                idx += 1
                continue
            }

            if !quoteBuffer.isEmpty { flushQuote() }
            paragraphBuffer.append(line)
            idx += 1
        }

        flushParagraph(); flushUL(); flushOL(); flushQuote()
        return items
    }
}


