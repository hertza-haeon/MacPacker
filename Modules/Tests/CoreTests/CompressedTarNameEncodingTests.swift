//
//  CompressedTarNameEncodingTests.swift
//  Modules
//
//  MacPacker Lab: a tar.gz, tar.xz or tar.bz2 is saved by writing its tar
//  again whole, and 7-Zip writes a tar's names in UTF-8. Names read in a code
//  page before the save are in UTF-8 after it, and read as that.
//

import Foundation
import Testing
@testable import Core

extension AllCoreTests {
    @MainActor struct CompressedTarNameEncodingTests {
        /// What `gbk.tar` holds, its names stored in GBK.
        private static let gbkTree = [
            "中文目录", "中文目录/你好世界.txt", "图片", "图片/风景.txt", "一些.txt"].sorted()

        private func makeFolder() throws -> URL {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("CompressedTarNameEncodingTests_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }

        /// `gbk.tar` from the test archives, gzipped by macOS's gzip into
        /// `folder`.
        private func gbkTarGz(in folder: URL) throws -> URL {
            let fixture = try #require(Bundle.module.url(forResource: "encodings", withExtension: nil))
                .appendingPathComponent("gbk.tar")
            let tar = folder.appendingPathComponent("gbk.tar")
            try FileManager.default.copyItem(at: fixture, to: tar)
            let gzip = Process()
            gzip.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
            gzip.arguments = [tar.path]
            gzip.standardOutput = FileHandle.nullDevice
            gzip.standardError = FileHandle.nullDevice
            try gzip.run()
            gzip.waitUntilExit()
            #expect(gzip.terminationStatus == 0)
            return folder.appendingPathComponent("gbk.tar.gz")
        }

        private func opened(_ url: URL) async throws -> ArchiveState {
            let state = ArchiveState(catalog: ArchiveTypeCatalog(), engineSelector: ArchiveEngineSelector7zip())
            state.open(url: url)
            try await state.openTask?.value
            #expect(state.error == nil)
            return state
        }

        /// What the window shows: every row, by the names leading to it.
        private func tree(of state: ArchiveState) -> [String] {
            func path(_ item: ArchiveItem) -> String {
                guard let parent = item.parent.flatMap({ state.entries[$0] }), parent.type != .root
                else { return item.name }
                return path(parent) + "/" + item.name
            }
            return state.entries.values.filter { $0.type != .root }.map(path).sorted()
        }

        /// Takes the file at the top (`一些.txt`, as GBK reads it) out and saves
        /// in place. Returns its name as the window showed it.
        @discardableResult
        private func removeOneAndSave(_ state: ArchiveState) async throws -> String {
            let item = try #require(state.childItems?.first { $0.type == .file })
            state.remove(items: [item])
            let saving = try #require(state.save())
            await saving.value
            #expect(state.saveError == nil)
            return item.name
        }

        @Test func namesDetectedInACodePageReadRightAfterASave() async throws {
            let folder = try makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let state = try await opened(try gbkTarGz(in: folder))
            #expect(state.canBeEdited)
            #expect(state.nameEncoding == .gb18030)
            #expect(tree(of: state) == Self.gbkTree)

            try await removeOneAndSave(state)

            #expect(state.error == nil)
            #expect(state.nameEncoding == .utf8)
            #expect(tree(of: state) == Self.gbkTree.filter { $0 != "一些.txt" })
        }

        /// The names are written as the pick reads them, whatever detection
        /// says, and a pick is for names stored in it: after the save none are.
        @Test func namesPickedByHandAreWrittenAsShownAndReadRightAfterASave() async throws {
            let folder = try makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let state = try await opened(try gbkTarGz(in: folder))
            state.readNames(as: .dosLatin)
            try await state.openTask?.value
            #expect(state.chosenNameEncoding == .dosLatin)
            let shown = tree(of: state)
            #expect(shown != Self.gbkTree)

            let removed = try await removeOneAndSave(state)

            #expect(state.error == nil)
            #expect(state.chosenNameEncoding == nil)
            #expect(tree(of: state) == shown.filter { $0 != removed })
        }
    }
}
