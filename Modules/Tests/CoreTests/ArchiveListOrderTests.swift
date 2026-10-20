//
//  ArchiveListOrderTests.swift
//  Modules
//
//  MacPacker Lab: a large list is presorted cheaply before the exact sort,
//  and the order is the exact sort's, for every column and direction —
//  whatever the names: case, accents, numbers of any width, punctuation,
//  other scripts, the same name in several folders.
//

import Foundation
import Testing
@testable import Core

extension AllCoreTests {
    @MainActor struct ArchiveListOrderTests {
        /// More than the presort's floor, with every kind of name that orders
        /// differently in Finder than as bytes.
        static let keys: [ArchiveItemKey] = {
            var generator = SeededGenerator(seed: 42)
            let stems = ["Photo", "photo", "Résumé", "resume", "IMG_", "img-", "Ärger", "zebra", "Zebra", "a b", "ab",
                         "Report (", "report-", "file_name", "File Name", "日本語", "zoë", "Zoe", "über", "Uber", "#tag",
                         "_hidden", ".dot", "Ｗｉｄｅ", "x"]
            return (0..<3_000).map { i in
                let stem = stems[Int.random(in: 0..<stems.count, using: &generator)]
                let number = Int.random(in: 0...(i % 3 == 0 ? 9 : 5_000_000), using: &generator)
                let name = "\(stem)\(i % 2 == 0 ? " " : "")\(number)\(i % 7 == 0 ? ")" : "").\(["jpg", "JPG", "txt"][i % 3])"
                let folder = ["", "a/", "b/", "deep/er/"][Int.random(in: 0..<4, using: &generator)]
                let item = ArchiveItem(
                    name: name,
                    virtualPath: folder + name,
                    type: i % 11 == 0 ? .directory : .file,
                    compressedSize: Int.random(in: 0...20, using: &generator),
                    uncompressedSize: Int.random(in: 0...20, using: &generator),
                    modificationDate: i % 5 == 0 ? nil : Date(timeIntervalSinceReferenceDate: Double(Int.random(in: -50...50, using: &generator)) * 86_400),
                    posixPermissions: i % 4 == 0 ? nil : [0o644, 0o755, 0o600][i % 3])
                return ArchiveItemKey(item)
            }
        }()

        @Test(arguments: [ArchiveSortOrder.name, .compressedSize, .uncompressedSize, .modificationDate, .posixPermissions].map(\.rawValue),
              [true, false])
        func theOrderIsTheExactSorts(column: String, ascending: Bool) {
            let order = ArchiveListOrder(column: column, ascending: ascending)
            let presorted = order.sortedIndices(Self.keys).map { Self.keys[$0].id }
            let exact = Self.keys.sorted(by: order.isBefore).map(\.id)
            #expect(presorted == exact)
        }

        @Test func searchResultsWithoutAColumnAreInTheExactOrder() throws {
            let order = ArchiveListOrder(column: nil, ascending: true)
            // every name has a dot
            let found = try #require(order.searched(Self.keys, for: ".")).map(\.id)
            #expect(found.count == Self.keys.count)
            let exact = Self.keys.sorted { a, b in
                if a.isFolder != b.isFolder { return a.isFolder }
                let cmp = a.name.localizedStandardCompare(b.name)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return ArchiveListOrder.isBeforeByPath(a, b)
            }.map(\.id)
            #expect(found == exact)
        }

        /// Without a column, a folder keeps the order the archive lists it in.
        @Test func noColumnKeepsTheArchivesOrder() {
            let order = ArchiveListOrder(column: nil, ascending: true)
            #expect(order.sortedIndices(Self.keys) == Array(Self.keys.indices))
        }
    }
}

/// The same names every run, so a failure can be looked at again.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state ^ (state >> 33)
    }
}
