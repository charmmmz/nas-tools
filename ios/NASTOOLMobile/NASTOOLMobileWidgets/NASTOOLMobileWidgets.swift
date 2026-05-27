@preconcurrency import ActivityKit
import SwiftUI
import WidgetKit

struct NASTOOLStatusEntry: TimelineEntry {
    let date: Date
}

struct NASTOOLStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> NASTOOLStatusEntry {
        NASTOOLStatusEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (NASTOOLStatusEntry) -> Void) {
        completion(NASTOOLStatusEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NASTOOLStatusEntry>) -> Void) {
        completion(Timeline(entries: [NASTOOLStatusEntry(date: .now)], policy: .never))
    }
}

struct NASTOOLStatusWidgetView: View {
    let entry: NASTOOLStatusEntry

    var body: some View {
        Text("NASTOOL")
            .font(.headline)
            .containerBackground(.background, for: .widget)
    }
}

struct NASTOOLStatusWidget: Widget {
    let kind = "NASTOOLStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NASTOOLStatusProvider()) { entry in
            NASTOOLStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("NASTOOL")
        .description("Quick NASTOOL status.")
    }
}

struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            DownloadLiveActivityView(state: context.state)
                .padding()
                .activityBackgroundTint(.black.opacity(0.82))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress.rounded()))%")
                        .font(.headline.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress, total: 100)
                }
            } compactLeading: {
                Image(systemName: "arrow.down.circle")
            } compactTrailing: {
                Text("\(Int(context.state.progress.rounded()))%")
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "arrow.down.circle")
            }
        }
    }
}

private struct DownloadLiveActivityView: View {
    let state: DownloadActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(state.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("\(Int(state.progress.rounded()))%")
                    .font(.headline.monospacedDigit())
            }

            ProgressView(value: state.progress, total: 100)

            Text(state.speedText.isEmpty ? state.state : state.speedText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

@main
struct NASTOOLMobileWidgets: WidgetBundle {
    var body: some Widget {
        NASTOOLStatusWidget()
        DownloadLiveActivityWidget()
    }
}
