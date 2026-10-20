//
//  BackgroundSearchTests.swift
//  Modules
//
//  MacPacker Lab: a large archive is searched off the main actor once typing
//  pauses. Its results are those the search on the main actor gives, only
//  the last of quick keystrokes is searched for, and a search that was left
//  shows nothing late.
//

import Foundation
import Swift7zip
import Testing
@testable import Core

extension AllCoreTests {
    @MainActor struct BackgroundSearchTests {
        private func openedState() async throws -> (ArchiveState, URL) {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("BackgroundSearchTests_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let archive = folder.appendingPathComponent("search.zip")
            let paths = ["a/dup.txt", "b/dup.txt", "c/dup.txt", "c/other.txt", "dupe notes.md", "readme.txt"]
            try SevenZipArchive.writeArchive(
                destination: archive,
                items: paths.map { .addData(archivePath: $0, data: Data($0.utf8)) },
                options: .init(format: .zip))

            let state = ArchiveState(catalog: ArchiveTypeCatalog(), engineSelector: ArchiveEngineSelector7zip())
            state.open(url: archive)
            try await state.openTask?.value
            return (state, folder)
        }

        private func shown(_ state: ArchiveState) -> [String] {
            state.childItems?.map { $0.virtualPath ?? $0.name } ?? []
        }

        @Test func theResultsAreThoseOfTheSearchOnTheMainActor() async throws {
            let (state, folder) = try await openedState()
            defer { try? FileManager.default.removeItem(at: folder) }

            state.search("dup")
            let onMain = shown(state)
            #expect(!onMain.isEmpty)
            state.search("")

            state.searchInBackgroundAbove = 0
            state.search("dup")
            await state.searchTask?.value
            #expect(shown(state) == onMain)
        }

        @Test func onlyTheLastOfQuickKeystrokesIsSearchedFor() async throws {
            let (state, folder) = try await openedState()
            defer { try? FileManager.default.removeItem(at: folder) }
            state.searchInBackgroundAbove = 0
            let folderShown = shown(state)

            state.search("r")
            let first = state.searchTask
            state.search("re")
            state.search("rea")
            await first?.value
            #expect(shown(state) == folderShown, "the first keystroke's search was dropped")

            await state.searchTask?.value
            #expect(shown(state) == ["readme.txt"])
        }

        @Test func aSearchLeftShowsNothingLate() async throws {
            let (state, folder) = try await openedState()
            defer { try? FileManager.default.removeItem(at: folder) }
            state.searchInBackgroundAbove = 0
            let folderShown = shown(state)

            state.search("dup")
            let pending = state.searchTask
            state.search("")
            await pending?.value
            #expect(shown(state) == folderShown)
        }
    }
}
