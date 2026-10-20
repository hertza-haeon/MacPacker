//
//  FinishedJobNoticesTests.swift
//  Modules
//
//  MacPacker Lab: a job that ran long and ended is said once; a short one,
//  a stopped one, or one still running is not.
//

import Foundation
import Testing
@testable import Core

extension AllCoreTests {
    struct FinishedJobNoticesTests {
        private static func job(
            _ kind: ExtractionJob.Kind = .extraction,
            ran duration: TimeInterval,
            ended state: ExtractionJob.State
        ) -> ExtractionJob {
            let start = Date(timeIntervalSinceNow: -duration)
            var job = ExtractionJob(
                id: UUID(), kind: kind, archiveName: "photos.zip", destination: nil,
                shownIn: nil, itemCount: 1, totalBytes: nil, startedAt: start)
            job.state = state
            if state != .running { job.finishedAt = start.addingTimeInterval(duration) }
            return job
        }

        @Test(arguments: [
            ExtractionJob.State.done,
            .failed("Disk full"),
        ])
        func aLongJobThatEndedIsSaidOnce(state: ExtractionJob.State) {
            var notices = FinishedJobNotices()
            let job = Self.job(ran: 30, ended: state)

            #expect(notices.newlyFinished(in: [job]).map(\.id) == [job.id])
            #expect(notices.newlyFinished(in: [job]).isEmpty, "said already")
        }

        @Test func aShortJobIsNotSaid() {
            var notices = FinishedJobNotices()
            let job = Self.job(ran: FinishedJobNotices.minimumDuration - 1, ended: .done)
            #expect(notices.newlyFinished(in: [job]).isEmpty)
        }

        @Test func aStoppedJobIsNotSaid() {
            var notices = FinishedJobNotices()
            #expect(notices.newlyFinished(in: [Self.job(ran: 60, ended: .cancelled)]).isEmpty)
        }

        @Test func aRunningJobIsSaidOnceItEnds() {
            var notices = FinishedJobNotices()
            var job = Self.job(.compression, ran: 30, ended: .running)
            #expect(notices.newlyFinished(in: [job]).isEmpty)

            job.state = .done
            job.finishedAt = Date()
            #expect(notices.newlyFinished(in: [job]).map(\.kind) == [.compression])
        }

        /// Several ending together are each said, whatever else is listed.
        @Test func eachJobIsSaidForItself() {
            var notices = FinishedJobNotices()
            let first = Self.job(ran: 20, ended: .done)
            let second = Self.job(.test, ran: 40, ended: .done)
            let running = Self.job(ran: 40, ended: .running)
            #expect(Set(notices.newlyFinished(in: [first, running, second]).map(\.id)) == [first.id, second.id])
        }
    }
}
