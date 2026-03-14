import Foundation
import UniformTypeIdentifiers

/// On-device email parsing for non-Gmail users via the iOS Share sheet.
/// When a user shares an email from Mail.app (or any email client), this service
/// extracts the text content and runs it through BookingParser to detect travel bookings.
final class ShareSheetParser {
    private let bookingParser = BookingParser()

    /// Content types we accept from the Share sheet.
    static let acceptedTypes: [UTType] = [
        .plainText,
        .html,
        .emailMessage,
        .url
    ]

    /// Parses shared content (from a Share sheet extension) into a booking.
    func parseSharedContent(_ content: SharedEmailContent) async -> ParsedBooking? {
        // Build a GmailMessage-shaped object from the shared content
        // so we can reuse BookingParser
        let message = GmailMessage(
            id: UUID().uuidString,
            threadId: "",
            snippet: String(content.body.prefix(200)),
            payload: GmailPayload(
                mimeType: content.isHTML ? "text/html" : "text/plain",
                headers: [
                    GmailHeader(name: "From", value: content.senderEmail ?? ""),
                    GmailHeader(name: "Subject", value: content.subject ?? "")
                ],
                body: GmailBody(
                    data: content.body.data(using: .utf8)?.base64EncodedString(),
                    size: content.body.count
                ),
                parts: nil
            )
        )

        return try? await bookingParser.parse(email: message)
    }

    /// Extracts email content from raw shared data (NSItemProvider results).
    func extractContent(
        text: String? = nil,
        html: String? = nil,
        url: URL? = nil
    ) -> SharedEmailContent {
        let body: String
        let isHTML: Bool

        if let html = html {
            body = stripHTML(html)
            isHTML = true
        } else if let text = text {
            body = text
            isHTML = false
        } else if let url = url {
            body = url.absoluteString
            isHTML = false
        } else {
            body = ""
            isHTML = false
        }

        // Try to extract sender and subject from the body
        let sender = extractSender(from: body)
        let subject = extractSubject(from: body)

        return SharedEmailContent(
            body: body,
            isHTML: isHTML,
            senderEmail: sender,
            subject: subject
        )
    }

    // MARK: - HTML Stripping

    private func stripHTML(_ html: String) -> String {
        // Remove HTML tags
        var text = html.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " ")
        ]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        // Collapse whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Heuristic Extraction

    private func extractSender(from text: String) -> String? {
        let patterns = [
            "from:\\s*([\\w.+-]+@[\\w.-]+)",
            "From:\\s*.*?<([\\w.+-]+@[\\w.-]+)>"
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matched = String(text[match])
                if let emailRange = matched.range(of: "[\\w.+-]+@[\\w.-]+", options: .regularExpression) {
                    return String(matched[emailRange])
                }
            }
        }
        return nil
    }

    private func extractSubject(from text: String) -> String? {
        let pattern = "subject:\\s*(.+?)\\n"
        if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            let line = String(text[match])
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count > 1 {
                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}

/// Represents email content extracted from a Share sheet action.
struct SharedEmailContent {
    let body: String
    let isHTML: Bool
    let senderEmail: String?
    let subject: String?
}
