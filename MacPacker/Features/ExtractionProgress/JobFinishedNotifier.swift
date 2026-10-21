//
//  JobFinishedNotifier.swift
//  MacPacker
//
//  MacPacker Lab: a notification when a long extraction, compression or test
//  ends while MacPacker is in the background — which is when nobody is
//  watching its window. Settings ▸ General turn them off and say how long is
//  long. macOS asks the user once whether to allow them, the first time one is
//  due, and System Settings keeps the answer.
//

import AppKit
import Combine
import Core
import UserNotifications

@MainActor
final class JobFinishedNotifier {
    private var notices = FinishedJobNotices()
    private var subscription: AnyCancellable?

    init(center: ExtractionProgressCenter) {
        subscription = center.$jobs.sink { [weak self] jobs in
            // published from the main actor, where the center lives
            MainActor.assumeIsolated { self?.jobsChanged(jobs) }
        }
    }

    private func jobsChanged(_ jobs: [ExtractionJob]) {
        // looked at every time, so a job that ends while the app is in front,
        // or while notifications are off, is not said later on
        let due = notices.newlyFinished(in: jobs, after: FinishedJobNotices.minimumDuration())
        guard !due.isEmpty, FinishedJobNotices.isOn(), !NSApp.isActive else { return }
        for job in due {
            post(title: Self.title(of: job), body: Self.body(of: job), id: job.id.uuidString)
        }
    }

    private func post(title: String, body: String, id: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
        }
    }

    private static func title(of job: ExtractionJob) -> String {
        let failed: Bool
        if case .failed = job.state { failed = true } else { failed = false }
        switch job.kind {
        case .extraction:
            return String(localized: failed ? .notificationExtractionFailed : .notificationExtractionFinished)
        case .compression:
            return String(localized: failed ? .notificationCompressionFailed : .notificationCompressionFinished)
        case .test:
            // what the test found is in the window's alert, waiting
            return String(localized: .notificationTestFinished)
        }
    }

    private static func body(of job: ExtractionJob) -> String {
        if case .failed(let message) = job.state {
            return "\(job.archiveName)\n\(message)"
        }
        return job.archiveName
    }
}
