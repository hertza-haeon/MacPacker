//
//  FinishedJobNoticesTests.swift
//  Modules
//
//  MacPacker Lab: a job that ran at least the chosen duration and ended is
//  said once; a shorter one, a stopped one, or one still running is not. The
//  settings read as Settings ▸ General show them.
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

            #expect(notices.newlyFinished(in: [job], after: 15).map(\.id) == [job.id])
            #expect(notices.newlyFinished(in: [job], after: 15).isEmpty, "said already")
        }

        /// A job is said from the chosen duration on, not a second sooner.
        @Test(arguments: FinishedJobNotices.durationChoices)
        func aJobIsSaidFromTheChosenDurationOn(seconds: Int) {
            var notices = FinishedJobNotices()
            let short = Self.job(ran: TimeInterval(seconds - 1), ended: .done)
            let long = Self.job(ran: TimeInterval(seconds), ended: .done)
            #expect(notices.newlyFinished(in: [short, long], after: TimeInterval(seconds)).map(\.id) == [long.id])
        }

        @Test func aStoppedJobIsNotSaid() {
            var notices = FinishedJobNotices()
            #expect(notices.newlyFinished(in: [Self.job(ran: 60, ended: .cancelled)], after: 15).isEmpty)
        }

        @Test func aRunningJobIsSaidOnceItEnds() {
            var notices = FinishedJobNotices()
            var job = Self.job(.compression, ran: 30, ended: .running)
            #expect(notices.newlyFinished(in: [job], after: 15).isEmpty)

            job.state = .done
            job.finishedAt = Date()
            #expect(notices.newlyFinished(in: [job], after: 15).map(\.kind) == [.compression])
        }

        /// What the progress center publishes as a job ends — marked done, then
        /// given its end time, one change at a time — is said once.
        @MainActor @Test func aJobEndedInTheProgressCenterIsSaidOnce() {
            let center = ExtractionProgressCenter()
            var notices = FinishedJobNotices()
            var said: [UUID] = []
            let subscription = center.$jobs.sink { jobs in
                said += notices.newlyFinished(in: jobs, after: 0).map(\.id)
            }
            defer { subscription.cancel() }

            let id = center.begin(kind: .test, archiveName: "photos.zip", destination: nil,
                                  itemCount: 1, totalBytes: nil)
            center.finish(id, .done)
            #expect(said == [id])
        }

        /// Several ending together are each said, whatever else is listed.
        @Test func eachJobIsSaidForItself() {
            var notices = FinishedJobNotices()
            let first = Self.job(ran: 20, ended: .done)
            let second = Self.job(.test, ran: 40, ended: .done)
            let running = Self.job(ran: 40, ended: .running)
            #expect(Set(notices.newlyFinished(in: [first, running, second], after: 15).map(\.id)) == [first.id, second.id])
        }

        /// Untouched, notifications are on, from 15 seconds.
        @Test func untouchedSettingsAreOnFromFifteenSeconds() {
            let defaults = isolatedDefaults()
            #expect(FinishedJobNotices.isOn(in: defaults))
            #expect(FinishedJobNotices.minimumDuration(in: defaults) == 15)
        }

        @Test func theChosenSettingsAreRead() {
            let defaults = isolatedDefaults()
            defaults.set(false, forKey: Keys.notifyFinishedJobs)
            defaults.set(60, forKey: Keys.notifyFinishedJobsAfter)
            #expect(!FinishedJobNotices.isOn(in: defaults))
            #expect(FinishedJobNotices.minimumDuration(in: defaults) == 60)
        }

        /// A duration Settings don't offer — the old 10 seconds, say — counts
        /// as the default.
        @Test(arguments: [0, 10, 45, 3600])
        func aDurationNotOfferedCountsAsTheDefault(seconds: Int) {
            let defaults = isolatedDefaults()
            defaults.set(seconds, forKey: Keys.notifyFinishedJobsAfter)
            #expect(FinishedJobNotices.minimumDuration(in: defaults) == TimeInterval(FinishedJobNotices.defaultDuration))
        }

        /// What the app registers as it starts is what a first launch reads.
        @Test func theDefaultsAreRegistered() {
            Keys.registerDefaults()
            let registered = UserDefaults.standard.volatileDomain(forName: UserDefaults.registrationDomain)
            #expect(registered[Keys.notifyFinishedJobs] as? Bool == true)
            #expect(registered[Keys.notifyFinishedJobsAfter] as? Int == FinishedJobNotices.defaultDuration)
        }
    }
}
