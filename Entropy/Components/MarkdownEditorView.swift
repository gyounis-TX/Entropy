import SwiftUI

/// A markdown-flavored text editor with a formatting toolbar.
/// Supports headers, bold, italic, lists, links, and code.
struct MarkdownEditorView: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)

    var body: some View {
        VStack(spacing: 0) {
            // Formatting toolbar
            if isFocused {
                formattingToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Editor with live preview interleaving
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .font(.body)
        }
    }

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                FormatButton(icon: "bold", label: "Bold") { wrapSelection(with: "**") }
                FormatButton(icon: "italic", label: "Italic") { wrapSelection(with: "_") }
                FormatButton(icon: "strikethrough", label: "Strikethrough") { wrapSelection(with: "~~") }

                Divider().frame(height: 20)

                FormatButton(icon: "number", label: "H1") { prefixLine(with: "# ") }
                FormatButton(icon: "textformat.size.smaller", label: "H2") { prefixLine(with: "## ") }
                FormatButton(icon: "textformat.size.smaller", label: "H3") { prefixLine(with: "### ") }

                Divider().frame(height: 20)

                FormatButton(icon: "list.bullet", label: "Bullet") { prefixLine(with: "- ") }
                FormatButton(icon: "list.number", label: "Numbered") { prefixNumberedList() }
                FormatButton(icon: "checklist", label: "Checklist") { prefixLine(with: "- [ ] ") }

                Divider().frame(height: 20)

                FormatButton(icon: "link", label: "Link") { insertLink() }
                FormatButton(icon: "chevron.left.forwardslash.chevron.right", label: "Code") { wrapSelection(with: "`") }
                FormatButton(icon: "text.quote", label: "Quote") { prefixLine(with: "> ") }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Formatting Actions

    private func wrapSelection(with marker: String) {
        // Insert markers around cursor position or wrap selected text
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // Simple approach: append markers at cursor-like position (end of text if no selection)
        text += "\(marker)text\(marker)"
    }

    private func prefixLine(with prefix: String) {
        if text.isEmpty || text.hasSuffix("\n") {
            text += prefix
        } else {
            text += "\n\(prefix)"
        }
    }

    private func prefixNumberedList() {
        // Count existing numbered items to determine next number
        let lines = text.components(separatedBy: "\n")
        let lastNumbered = lines.reversed().first { line in
            line.range(of: "^\\d+\\.", options: .regularExpression) != nil
        }
        let nextNum: Int
        if let last = lastNumbered,
           let numStr = last.split(separator: ".").first,
           let num = Int(numStr) {
            nextNum = num + 1
        } else {
            nextNum = 1
        }

        if text.isEmpty || text.hasSuffix("\n") {
            text += "\(nextNum). "
        } else {
            text += "\n\(nextNum). "
        }
    }

    private func insertLink() {
        text += "[link text](url)"
    }
}

struct FormatButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Markdown Preview

/// Renders markdown text as styled SwiftUI content.
struct MarkdownPreview: View {
    let markdown: String

    var body: some View {
        if #available(iOS 18.0, *) {
            // Use native markdown rendering
            Text(attributedMarkdown)
                .textSelection(.enabled)
        } else {
            // Fallback: basic styled rendering
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(markdown.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    markdownLine(line)
                }
            }
        }
    }

    private var attributedMarkdown: AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        ))) ?? AttributedString(markdown)
    }

    @ViewBuilder
    private func markdownLine(_ line: String) -> some View {
        if line.hasPrefix("### ") {
            Text(line.dropFirst(4))
                .font(.headline)
        } else if line.hasPrefix("## ") {
            Text(line.dropFirst(3))
                .font(.title3)
                .fontWeight(.bold)
        } else if line.hasPrefix("# ") {
            Text(line.dropFirst(2))
                .font(.title2)
                .fontWeight(.bold)
        } else if line.hasPrefix("> ") {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(.blue.opacity(0.5))
                    .frame(width: 3)
                Text(line.dropFirst(2))
                    .font(.body)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        } else if line.hasPrefix("- [ ] ") {
            HStack(spacing: 6) {
                Image(systemName: "square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(line.dropFirst(6))
            }
        } else if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.square.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text(line.dropFirst(6))
                    .strikethrough()
                    .foregroundStyle(.secondary)
            }
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                Text(line.dropFirst(2))
            }
        } else if line.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
            Text(styledInline(line))
        } else {
            Text(styledInline(line))
        }
    }

    /// Handles inline formatting: **bold**, _italic_, ~~strikethrough~~, `code`
    private func styledInline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        ))) ?? AttributedString(text)
    }
}
