//
//  SwcExtractionErrorTests.swift
//  Modules
//
//  MacPacker Lab: an `.lz4` that SWCompression cannot decompress fails to
//  extract, and says so. It used to be reported as extracted, with nothing
//  written — and, with "Move the archive to the Trash" on, binned too.
//
//  The files are made here from the bundled `defaultArchive.tar.lz4`: as it is
//  under a plain `.lz4` name, cut in half, or nothing but noise.
//

import Foundation
import Testing
@testable import Core

extension AllCoreTests {
    @MainActor struct SwcExtractionErrorTests {
        private static func makeFolder() throws -> URL {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("SwcExtractionErrorTests_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }

        /// `kind`: "whole" as bundled, "half" cut in half, "noise" random bytes.
        private static func makeArchive(_ kind: String, in folder: URL) throws -> URL {
            let fixtures = try #require(Bundle.module.url(forResource: "defaultArchives", withExtension: nil))
            let bytes = try Data(contentsOf: fixtures.appendingPathComponent("defaultArchive.tar.lz4"))
            let archive = folder.appendingPathComponent("\(kind).lz4")
            switch kind {
            case "half": try bytes.prefix(bytes.count / 2).write(to: archive)
            case "noise": try Data((0..<256).map { _ in UInt8.random(in: 0...255) }).write(to: archive)
            default: try bytes.write(to: archive)
            }
            return archive
        }

        private static func openedState(_ archive: URL) async throws -> ArchiveState {
            let catalog = ArchiveTypeCatalog()
            let store = ArchiveEngineConfigStore(catalog: catalog, defaults: UserDefaults(suiteName: UUID().uuidString)!)
            let state = ArchiveState(catalog: catalog, engineSelector: ArchiveEngineSelector(catalog: catalog, configStore: store))
            state.progressCenter = ExtractionProgressCenter()
            state.open(url: archive)
            try await state.openTask?.value
            #expect(state.activeEngine == .swc)
            return state
        }

        private static func destination(in folder: URL) throws -> URL {
            let out = folder.appendingPathComponent("out", isDirectory: true)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            return out
        }

        @Test func anIntactArchiveStillExtracts() async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let state = try await Self.openedState(try Self.makeArchive("whole", in: folder))
            let out = try Self.destination(in: folder)

            #expect(await state.extract(to: out, smart: false).value == .done)
            let written = try FileManager.default.contentsOfDirectory(atPath: out.path)
            #expect(written == ["whole"])
            let size = try out.appendingPathComponent("whole").resourceValues(forKeys: [.fileSizeKey]).fileSize
            #expect((size ?? 0) > 0)
        }

        @Test(arguments: ["half", "noise"])
        func aBrokenArchiveFailsToExtractWhole(kind: String) async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let state = try await Self.openedState(try Self.makeArchive(kind, in: folder))
            let out = try Self.destination(in: folder)

            let outcome = await state.extract(to: out, smart: false).value
            guard case .failed = outcome else {
                Issue.record("reported \(outcome)")
                return
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: out.path).isEmpty)
        }

        @Test(arguments: ["half", "noise"])
        func aBrokenArchiveFailsToExtractItsItem(kind: String) async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let state = try await Self.openedState(try Self.makeArchive(kind, in: folder))
            let out = try Self.destination(in: folder)
            let item = try #require(state.entries.values.first { $0.type == .file })

            let outcome = await state.extract(items: [item], to: out, smart: false).value
            guard case .failed = outcome else {
                Issue.record("reported \(outcome)")
                return
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: out.path).isEmpty)
        }
    }
}
