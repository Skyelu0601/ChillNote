import WidgetKit
import SwiftUI
import AppIntents

struct ChillNoteWidget: Widget {
    let kind: String = "ChillNoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            QuickCaptureWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Quick Capture"))
        .description(String(localized: "Instantly start recording your thoughts."))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct QuickCaptureWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title2)
            }
            .widgetURL(URL(string: "chillnote://record"))
            
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.accentColor)
                Text("ChillNote")
                    .fontWeight(.bold)
            }
            .containerBackground(.clear, for: .widget)
            .widgetURL(URL(string: "chillnote://record"))
            
        default:
            VStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white)
                            .font(.title)
                    )
                Text(String(localized: "Record"))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .containerBackground(.clear, for: .widget)
            .widgetURL(URL(string: "chillnote://record"))
        }
    }
}
