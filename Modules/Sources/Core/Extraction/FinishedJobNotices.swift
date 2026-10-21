//
//  FinishedJobNotices.swift
//  Modules
//
//  MacPacker Lab: which finished jobs are worth a notification — those long
//  enough that the user has turned to something else. Whether they have is
//  for the app to say: it posts only while it is not the active app. Whether
//  to post at all, and how long is long, are settings (Settings ▸ General).
//

import Foundation

public struct FinishedJobNotices {
    /// How long a job runs, in seconds, before its end is worth saying, as
    /// Settings offer it: one over sooner is over before anyone has looked away.
    public static let durationChoices = [15, 30, 60]
    /// The choice until the user makes one.
    public static let defaultDuration = 15

    /// Whether finished jobs are told at all. On unless turned off.
    public static func isOn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: Keys.notifyFinishedJobs) as? Bool ?? true
    }

    /// The chosen duration. Anything Settings don't offer — unset, or written
    /// by hand — counts as the default.
    public static func minimumDuration(in defaults: UserDefaults = .standard) -> TimeInterval {
        let chosen = defaults.integer(forKey: Keys.notifyFinishedJobsAfter)
        return TimeInterval(durationChoices.contains(chosen) ? chosen : defaultDuration)
    }

    /// The jobs already looked at once finished, so each is said once.
    private var seen: Set<UUID> = []

    public init() {}

    /// The jobs in `jobs` that have finished since the last call, ran at
    /// least `minimumDuration`, and were not stopped by the user — who knows
    /// about those already.
    public mutating func newlyFinished(in jobs: [ExtractionJob], after minimumDuration: TimeInterval) -> [ExtractionJob] {
        var due: [ExtractionJob] = []
        for job in jobs where job.isFinished && !seen.contains(job.id) {
            seen.insert(job.id)
            guard job.state != .cancelled,
                  let end = job.finishedAt,
                  end.timeIntervalSince(job.startedAt) >= minimumDuration else { continue }
            due.append(job)
        }
        // the jobs that are gone are forgotten; their ids never come back
        seen.formIntersection(jobs.map(\.id))
        return due
    }
}
