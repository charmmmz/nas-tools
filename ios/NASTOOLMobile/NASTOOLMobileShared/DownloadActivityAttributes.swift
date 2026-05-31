@preconcurrency import ActivityKit
import Foundation

struct DownloadActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let title: String
        let speedText: String
        let state: String
        let progress: Double
        let updatedAt: Date

        init(title: String, speedText: String, state: String, progress: Double, updatedAt: Date = .now) {
            self.title = title
            self.speedText = speedText
            self.state = state
            self.progress = min(max(progress, 0), 100)
            self.updatedAt = updatedAt
        }
    }

    let downloadID: String
}
