import SwiftUI

struct DownloadsView: View {
    @State private var store: DownloadsStore
    @State private var liveActivityController = LiveActivityController()

    init(api: DownloadsAPI) {
        _store = State(initialValue: DownloadsStore(api: api))
    }

    var body: some View {
        List {
            if let errorMessage = store.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if store.tasks.isEmpty {
                if store.isLoading {
                    ProgressView()
                } else {
                    ContentUnavailableView("No Downloads", systemImage: "tray")
                }
            } else {
                ForEach(store.tasks) { task in
                    DownloadTaskRow(
                        task: task,
                        onTrack: {
                            Task {
                                await liveActivityController.startOrUpdate(task: task)
                            }
                        },
                        onToggle: {
                            Task {
                                if task.isDownloading {
                                    await store.pause(task.id)
                                } else {
                                    await store.start(task.id)
                                }
                            }
                        },
                        onRemove: {
                            Task {
                                await store.remove(task.id)
                            }
                        }
                    )
                }
            }
        }
        .navigationTitle("Downloads")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await store.load()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh Downloads")
            }
        }
        .refreshable {
            await store.load()
        }
        .task {
            await store.load()
            store.connectEvents()
        }
        .onDisappear {
            store.disconnectEvents()
        }
    }
}

private struct DownloadTaskRow: View {
    let task: DownloadTask
    let onTrack: () -> Void
    let onToggle: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.displayTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Text(task.speedText.isEmpty ? task.state : task.speedText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text("\(Int(task.progress.rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(max(task.progress, 0), 100), total: 100)

            HStack {
                Button(action: onTrack) {
                    Image(systemName: "livephoto")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Track Live Activity")

                Button(action: onToggle) {
                    Image(systemName: task.isDownloading ? "pause.circle" : "play.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(task.isDownloading ? "Pause Download" : "Start Download")

                Spacer()

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove Download")
            }
            .font(.title3)
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button("Track Live Activity", action: onTrack)
            Button(task.isDownloading ? "Pause" : "Start", action: onToggle)
            Button("Remove", role: .destructive, action: onRemove)
        }
    }
}

#Preview {
    NavigationStack {
        DownloadsView(api: PreviewDownloadsAPI())
    }
}

private struct PreviewDownloadsAPI: DownloadsAPI {
    func fetchDownloading() async throws -> NastoolResultResponse<[DownloadTask]> {
        NastoolResultResponse(
            code: 0,
            success: true,
            message: nil,
            msg: nil,
            total: 1,
            result: [
                DownloadTask(
                    id: "preview",
                    name: "Preview",
                    title: "Example Movie",
                    speedText: "down 1.2MB/s up 30KB/s 10m",
                    state: "Downloading",
                    progress: 42
                )
            ]
        )
    }

    func startDownload(id: String) async throws -> NastoolCommandResponse {
        NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    func stopDownload(id: String) async throws -> NastoolCommandResponse {
        NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }

    func removeDownload(id: String) async throws -> NastoolCommandResponse {
        NastoolCommandResponse(code: 0, retcode: nil, success: true, message: nil, msg: nil, retmsg: nil)
    }
}
