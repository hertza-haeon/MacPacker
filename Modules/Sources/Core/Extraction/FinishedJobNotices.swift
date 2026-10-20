//
//  FinishedJobNotices.swift
//  Modules
//
//  MacPacker Lab: which finished jobs are worth a notification — those long
//  enough that the user has turned to something else. Whether they have is
//  for the app to say: it posts only while it is not the active app.
//

import Foundation

public struct FinishedJobNotices {
    /// How long a job runs before its end is worth saying: one over sooner
    /// is over before anyone has looked away.
    public static let minimumDuration: TimeInterval = 10

    /// The jobs already looked at once finished, so each is said once.
    private var seen: Set<UUID> = []

    public init() {}

    /// The jobs in `jobs` that have finished since the last call, ran at
    /// least `minimumDuration`, and were not stopped by the user — who knows
    /// about those already.
    public mutating func newlyFinished(in jobs: [ExtractionJob]) -> [ExtractionJob] {
        var due: [ExtractionJob] = []
        for job in jobs where job.isFinished && !seen.contains(job.id) {
            seen.insert(job.id)
            guard job.state != .cancelled,
                  let end = job.finishedAt,
                  end.timeIntervalSince(job.startedAt) >= Self.minimumDuration else { continue }
            due.append(job)
        }
        // the jobs that are gone are forgotten; their ids never come back
        seen.formIntersection(jobs.map(\.id))
        return due
    }
}
