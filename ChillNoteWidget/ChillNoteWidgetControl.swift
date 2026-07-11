import AppIntents
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, *)
struct ChillNoteWidgetControl: ControlWidget {
    private static let brainDumpControlURL = URL(string: "chillnote://record?source=control_widget")!

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.sponteoai.chillnote.brain_dump_control") {
            ControlWidgetButton(action: OpenURLIntent(Self.brainDumpControlURL)) {
                Label(
                    LocalizedStringResource("widget.brain_dump.control.title"),
                    systemImage: "waveform.and.mic"
                )
            }
        }
        .displayName(LocalizedStringResource("widget.brain_dump.control.display_name"))
        .description(LocalizedStringResource("widget.brain_dump.control.description"))
    }
}
