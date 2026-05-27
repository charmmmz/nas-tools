@preconcurrency import ActivityKit
import Foundation

extension DownloadActivityAttributes.ContentState {
    init(task: DownloadTask) {
        self.init(
            title: task.displayTitle,
            speedText: task.speedText,
            state: task.state,
            progress: task.progress
        )
    }
}

@MainActor
final class LiveActivityController {
    private var activitiesByDownloadID: [String: Activity<DownloadActivityAttributes>] = [:]

    func startOrUpdate(task: DownloadTask) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let content = ActivityContent(
            state: DownloadActivityAttributes.ContentState(task: task),
            staleDate: Calendar.current.date(byAdding: .minute, value: 10, to: .now)
        )

        if let activity = activitiesByDownloadID[task.id] {
            await activity.update(content)
            return
        }

        do {
            let activity = try Activity.request(
                attributes: DownloadActivityAttributes(downloadID: task.id),
                content: content,
                pushType: nil
            )
            activitiesByDownloadID[task.id] = activity
        } catch {
            return
        }
    }

    func end(taskID: String) async {
        guard let activity = activitiesByDownloadID.removeValue(forKey: taskID) else {
            return
        }

        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
