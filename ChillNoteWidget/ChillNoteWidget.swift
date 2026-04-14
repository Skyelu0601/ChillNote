import SwiftUI
import WidgetKit

private let brainDumpWidgetURL = URL(string: "chillnote://record?source=lockscreen_widget")!

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let timeline = Timeline(entries: [SimpleEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

// MARK: - Widget Configuration

struct ChillNoteWidget: Widget {
    let kind: String = "ChillNoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ChillNoteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.brain_dump.display_name"))
        .description(String(localized: "widget.brain_dump.description"))
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Entry View

struct ChillNoteWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            CircularWidgetView()
        } else {
            CircularWidgetView()
        }
    }
}

// MARK: - Lock Screen Widget Views

private struct CircularWidgetView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [WidgetPalette.accentStart, WidgetPalette.accentEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(6)
                .widgetAccentable()

            VStack(spacing: 3) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 2) {
                    ForEach(Array([6, 10, 14, 10, 6].enumerated()), id: \.offset) { _, height in
                        Capsule()
                            .fill(.white.opacity(0.9))
                            .frame(width: 2.5, height: CGFloat(height))
                    }
                }
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(brainDumpWidgetURL)
        .accessibilityLabel(Text(LocalizedStringResource("widget.brain_dump.accessibility.label")))
        .accessibilityHint(Text(LocalizedStringResource("widget.brain_dump.accessibility.hint")))
    }
}

// MARK: - Widget Palette

private enum WidgetPalette {
    static let accentStart = Color(red: 0.90, green: 0.64, blue: 0.33)
    static let accentEnd = Color(red: 0.92, green: 0.69, blue: 0.46)
}

// MARK: - Previews

#Preview(as: .accessoryCircular) {
    ChillNoteWidget()
} timeline: {
    SimpleEntry(date: .now)
}
