import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Quick Capture Widget

/// A small widget that provides one-tap access to create a new note in any category.
struct QuickCaptureWidget: Widget {
    let kind: String = "QuickCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Capture")
        .description("Quickly create a note in any category.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct QuickCaptureEntry: TimelineEntry {
    let date: Date
    let categories: [WidgetCategory]
}

struct WidgetCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let noteCount: Int
}

struct QuickCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(date: Date(), categories: placeholderCategories)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCaptureEntry) -> Void) {
        completion(QuickCaptureEntry(date: Date(), categories: placeholderCategories))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCaptureEntry>) -> Void) {
        let entry = QuickCaptureEntry(date: Date(), categories: loadCategories())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
    }

    private func loadCategories() -> [WidgetCategory] {
        guard let container = SharedModelContainer.create() else {
            return placeholderCategories
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<NoteCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        guard let categories = try? context.fetch(descriptor), !categories.isEmpty else {
            return placeholderCategories
        }

        return categories.prefix(3).map { cat in
            WidgetCategory(
                id: cat.id.uuidString,
                name: cat.name,
                icon: cat.icon ?? "folder.fill",
                color: cat.color ?? "blue",
                noteCount: cat.noteCount
            )
        }
    }

    private var placeholderCategories: [WidgetCategory] {
        [
            WidgetCategory(id: "work", name: "Work", icon: "briefcase.fill", color: "blue", noteCount: 0),
            WidgetCategory(id: "tilbury", name: "Tilbury", icon: "building.2.fill", color: "green", noteCount: 0),
            WidgetCategory(id: "laguna", name: "Laguna", icon: "house.fill", color: "orange", noteCount: 0)
        ]
    }
}

// MARK: - Widget Views

struct QuickCaptureWidgetView: View {
    let entry: QuickCaptureEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "note.text.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("Quick Note")
                    .font(.headline)
                Spacer()
            }

            Spacer()

            // Deep link to create note — opens app to note creation
            Link(destination: URL(string: "entropy://new-note")!) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Note")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(4)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text.badge.plus")
                    .foregroundStyle(.blue)
                Text("Quick Capture")
                    .font(.headline)
                Spacer()
            }

            // Category shortcuts
            HStack(spacing: 8) {
                ForEach(entry.categories) { category in
                    Link(destination: URL(string: "entropy://new-note?category=\(category.id)")!) {
                        VStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.title3)
                                .foregroundStyle(widgetColor(category.color))
                            Text(category.name)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(widgetColor(category.color).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Generic "New" button
                Link(destination: URL(string: "entropy://new-note")!) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        Text("New")
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(4)
    }

    private func widgetColor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .blue
        }
    }
}
