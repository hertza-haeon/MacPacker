//
//  ArchiveTestTests.swift
//  Modules
//
//  MacPacker Lab: "Test Archive" decodes every entry and checks it, writing
//  nothing, and names what does not decode. 7-Zip has a test mode of its own;
//  the other engines extract into a temporary folder that goes afterwards.
//

import Foundation
import Swift7zip
import Testing
@testable import Core

extension AllCoreTests {
    struct ArchiveTestTests {
        /// What b.txt holds: found again in a stored zip to damage it.
        private static let damageable = Data(String(repeating: "DAMAGE-ME-", count: 200).utf8)

        private static func makeFolder() throws -> URL {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("ArchiveTestTests_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }

        /// A stored zip of a.txt and b.txt, so b.txt's bytes are there as
        /// they are, to be changed.
        private static func makeZip(in folder: URL, password: String? = nil) throws -> URL {
            let archive = folder.appendingPathComponent("test.zip")
            try SevenZipArchive.writeArchive(
                destination: archive,
                items: [
                    .addData(archivePath: "a.txt", data: Data("hello".utf8)),
                    .addData(archivePath: "b.txt", data: damageable),
                ],
                options: .init(format: .zip, level: 0, password: password))
            return archive
        }

        /// One byte of b.txt changed, so its checksum no longer matches.
        private static func damage(_ archive: URL) throws {
            var bytes = try Data(contentsOf: archive)
            let range = try #require(bytes.range(of: damageable))
            let middle = range.lowerBound + range.count / 2
            bytes[middle] ^= 0xFF
            try bytes.write(to: archive)
        }

        private static let noPassword: ArchivePasswordResolver = { _ in nil }

        @Test func anIntactArchivePassesSevenZipsTest() async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = try Self.makeZip(in: folder)

            let report = try await Archive7ZipEngine().test(archive, passwordResolver: Self.noPassword, onProgress: nil)

            #expect(report.isIntact)
            #expect(report.damagedPaths.isEmpty)
            // nothing written beside it
            #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["test.zip"])
        }

        @Test func sevenZipsTestNamesTheDamagedEntry() async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = try Self.makeZip(in: folder)
            try Self.damage(archive)

            let report = try await Archive7ZipEngine().test(archive, passwordResolver: Self.noPassword, onProgress: nil)

            #expect(!report.isIntact)
            #expect(report.problem == "CRC error")
            #expect(report.damagedPaths == ["b.txt"])
        }

        /// XAD has no test of its own: it extracts to a temporary folder.
        @Test func anEngineWithoutATestExtractsToFindOut() async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = try Self.makeZip(in: folder)

            let intact = try await ArchiveXadEngine().test(archive, passwordResolver: Self.noPassword, onProgress: nil)
            #expect(intact.isIntact)

            try Self.damage(archive)
            let damaged = try await ArchiveXadEngine().test(archive, passwordResolver: Self.noPassword, onProgress: nil)
            #expect(!damaged.isIntact)
            #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["test.zip"])
        }

        @Test func anEncryptedArchiveIsTestedWithItsPassword() async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = try Self.makeZip(in: folder, password: "secret")
            let asked = Asked()

            let report = try await Archive7ZipEngine().test(archive, passwordResolver: { request in
                await asked.record(request.attempt)
                return request.attempt == 1 ? "wrong" : "secret"
            }, onProgress: nil)

            #expect(report.isIntact)
            #expect(await asked.attempts == [1, 2], "the wrong one asked again")
        }

        @Test func aPromptDismissedStopsTheTest() async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = try Self.makeZip(in: folder, password: "secret")

            await #expect(throws: ArchiveError.self) {
                _ = try await Archive7ZipEngine().test(archive, passwordResolver: Self.noPassword, onProgress: nil)
            }
        }

        @Test func aStopFromTheProgressEndsTheTest() async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = try Self.makeZip(in: folder)

            await #expect(throws: CancellationError.self) {
                _ = try await Archive7ZipEngine().test(archive, passwordResolver: Self.noPassword, onProgress: { _, _ in false })
            }
        }

        /// The attempts the resolver was asked for, in order.
        private actor Asked {
            private(set) var attempts: [Int] = []
            func record(_ attempt: Int) { attempts.append(attempt) }
        }
    }

    @MainActor struct ArchiveStateTestTests {
        @Test func theWindowSaysWhatTheTestFound() async throws {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("ArchiveStateTestTests_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = folder.appendingPathComponent("photos.zip")
            let content = Data(String(repeating: "DAMAGE-ME-", count: 200).utf8)
            try SevenZipArchive.writeArchive(
                destination: archive,
                items: [.addData(archivePath: "b.txt", data: content)],
                options: .init(format: .zip, level: 0))

            let state = ArchiveState(catalog: ArchiveTypeCatalog(), engineSelector: ArchiveEngineSelector7zip())
            let center = ExtractionProgressCenter()
            state.progressCenter = center
            state.open(url: archive)
            try await state.openTask?.value
            #expect(state.canTest)

            let intact = try #require(await state.test().value)
            #expect(intact.isIntact)
            #expect(intact.archiveName == "photos.zip")
            #expect(state.testResult == intact)
            #expect(center.jobs.last?.kind == .test)
            #expect(center.jobs.last?.state == .done)

            state.clearTestResult()
            var bytes = try Data(contentsOf: archive)
            let range = try #require(bytes.range(of: content))
            bytes[range.lowerBound + 10] ^= 0xFF
            try bytes.write(to: archive)

            let damaged = try #require(await state.test().value)
            #expect(damaged.damagedPaths == ["b.txt"])
            #expect(state.testResult == damaged)
        }

        /// Quitting under a test needs no warning: nothing is lost.
        @Test func aRunningTestIsNotWhatQuittingWarnsAbout() {
            let center = ExtractionProgressCenter()
            let test = center.begin(kind: .test, archiveName: "photos.zip", destination: nil, itemCount: 1, totalBytes: nil)
            #expect(center.hasActiveJobs)
            #expect(center.runningKind == nil)

            center.begin(kind: .compression, archiveName: "new.zip", destination: nil, itemCount: 1, totalBytes: nil)
            #expect(center.runningKind == .compression)
            center.finish(test, .done)
        }
    }
}
