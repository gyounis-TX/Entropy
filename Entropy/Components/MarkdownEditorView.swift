import SwiftUI
import UIKit

/// A markdown-flavored text editor with a formatting toolbar.
/// Supports headers, bold, italic, lists, links, and code.
struct MarkdownEditorView: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Formatting toolbar
            if isFocused {
                formattingToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Editor
            MarkdownTextView(text: $text, isFocused: $isFocused)
        }
    }

    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                FormatButton(icon: "bold", label: "Bold") {
                    MarkdownTextView.applyFormatting(.wrap("**"))
                }
                FormatButton(icon: "italic", label: "Italic") {
                    MarkdownTextView.applyFormatting(.wrap("_"))
                }
                FormatButton(icon: "strikethrough", label: "Strikethrough") {
                    MarkdownTextView.applyFormatting(.wrap("~~"))
                }

                Divider().frame(height: 20)

                FormatButton(icon: "number", label: "H1") {
                    MarkdownTextView.applyFormatting(.prefix("# "))
                }
                FormatButton(icon: "textformat.size.smaller", label: "H2") {
                    MarkdownTextView.applyFormatting(.prefix("## "))
                }
                FormatButton(icon: "textformat.size.smaller", label: "H3") {
                    MarkdownTextView.applyFormatting(.prefix("### "))
                }

                Divider().frame(height: 20)

                FormatButton(icon: "list.bullet", label: "Bullet") {
                    MarkdownTextView.applyFormatting(.prefix("- "))
                }
                FormatButton(icon: "list.number", label: "Numbered") {
                    MarkdownTextView.applyFormatting(.prefix("1. "))
                }
                FormatButton(icon: "checklist", label: "Checklist") {
                    MarkdownTextView.applyFormatting(.prefix("- [ ] "))
                }

                Divider().frame(height: 20)

                FormatButton(icon: "link", label: "Link") {
                    MarkdownTextView.applyFormatting(.insert("[link text](url)"))
                }
                FormatButton(icon: "chevron.left.forwardslash.chevron.right", label: "Code") {
                    MarkdownTextView.applyFormatting(.wrap("`"))
                }
                FormatButton(icon: "text.quote", label: "Quote") {
                    MarkdownTextView.applyFormatting(.prefix("> "))
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - UIKit-backed TextView with selection support

struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    enum FormattingAction {
        case wrap(String)      // Wrap selection: **selected** or insert **text**
        case prefix(String)    // Prefix current line: # Header
        case insert(String)    // Insert at cursor
    }

    // Static notification for toolbar actions
    static let formattingNotification = Notification.Name("MarkdownFormatting")

    static func applyFormatting(_ action: FormattingAction) {
        NotificationCenter.default.post(name: formattingNotification, object: action)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        context.coordinator.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @FocusState.Binding var isFocused: Bool
        weak var textView: UITextView?
        private var observer: NSObjectProtocol?

        init(text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
            _text = text
            _isFocused = isFocused
            super.init()

            observer = NotificationCenter.default.addObserver(
                forName: MarkdownTextView.formattingNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let action = notification.object as? FormattingAction else { return }
                self?.handleFormatting(action)
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isFocused = false
        }

        private func handleFormatting(_ action: FormattingAction) {
            guard let textView else { return }

            let selectedRange = textView.selectedRange
            let nsText = textView.text as NSString

            switch action {
            case .wrap(let marker):
                let selectedText = nsText.substring(with: selectedRange)
                if selectedText.isEmpty {
                    // No selection: insert placeholder
                    let insertion = "\(marker)text\(marker)"
                    textView.textStorage.replaceCharacters(in: selectedRange, with: insertion)
                    // Select the "text" part for easy replacement
                    let selectStart = selectedRange.location + marker.count
                    textView.selectedRange = NSRange(location: selectStart, length: 4)
                } else {
                    // Wrap the selection
                    let wrapped = "\(marker)\(selectedText)\(marker)"
                    textView.textStorage.replaceCharacters(in: selectedRange, with: wrapped)
                    let newStart = selectedRange.location + marker.count
                    textView.selectedRange = NSRange(location: newStart, length: selectedText.count)
                }

            case .prefix(let prefix):
                // Find the start of the current line
                let lineRange = nsText.lineRange(for: selectedRange)
                let lineText = nsText.substring(with: lineRange)

                // If line already has this prefix, remove it (toggle)
                if lineText.hasPrefix(prefix) {
                    let unprefixed = String(lineText.dropFirst(prefix.count))
                    textView.textStorage.replaceCharacters(in: lineRange, with: unprefixed)
                } else {
                    // Add prefix at the start of the line
                    let prefixed = prefix + lineText
                    textView.textStorage.replaceCharacters(in: lineRange, with: prefixed)
                    textView.selectedRange = NSRange(
                        location: selectedRange.location + prefix.count,
                        length: selectedRange.length
                    )
                }

            case .insert(let insertText):
                textView.textStorage.replaceCharacters(in: selectedRange, with: insertText)
                textView.selectedRange = NSRange(
                    location: selectedRange.location + insertText.count,
                    length: 0
                )
            }

            text = textView.text
        }
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
            Text(attributedMarkdown)
                .textSelection(.enabled)
        } else {
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

    private func styledInline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        ))) ?? AttributedString(text)
    }
}
