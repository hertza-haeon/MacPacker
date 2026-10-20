//
//  ArchiveListOrder.swift
//  Modules
//
//  MacPacker Lab: how the list is ordered and searched, on values taken from
//  the items. A search of a large archive runs off the main actor on such a
//  snapshot, while the items stay where they are.
//

import Foundation

/// An item as the list sorts and searches it.
struct ArchiveItemKey: Sendable {
    let id: UUID
    let name: String
    /// The path in the archive, or the name for an item without one.
    let path: String
    let isFolder: Bool
    let isRoot: Bool
    let modificationDate: Date?
    let uncompressedSize: Int
    let compressedSize: Int
    let posixPermissions: Int?

    @MainActor
    init(_ item: ArchiveItem) {
        id = item.id
        name = item.name
        path = item.virtualPath ?? item.name
        isFolder = item.isFolder
        isRoot = item.type == .root
        modificationDate = item.modificationDate
        uncompressedSize = item.uncompressedSize
        compressedSize = item.compressedSize
        posixPermissions = item.posixPermissions
    }
}

/// The order the user chose by clicking a column, or none.
struct ArchiveListOrder: Sendable {
    let column: String?
    let ascending: Bool

    static var current: ArchiveListOrder {
        ArchiveListOrder(
            column: UserDefaults.standard.string(forKey: Keys.defaultOrderColumn),
            ascending: UserDefaults.standard.bool(forKey: Keys.defaultOrderColumnAscending))
    }

    /// A folder's items in that order; without one, as the archive lists them.
    func sorted(_ keys: [ArchiveItemKey]) -> [ArchiveItemKey] {
        guard column != nil else { return keys }
        return keys.sorted(by: isBefore)
    }

    /// All items (any level) whose name contains `text`. Sorted like the
    /// browse view; without a stored order, by name — dictionary order would
    /// make the results jump around on every keystroke. `nil` when the task
    /// it runs in is cancelled first.
    func searched(_ keys: [ArchiveItemKey], for text: String) -> [ArchiveItemKey]? {
        var matches: [ArchiveItemKey] = []
        for (index, key) in keys.enumerated() {
            if index % 4096 == 0, Task.isCancelled { return nil }
            if !key.isRoot, key.name.localizedCaseInsensitiveContains(text) {
                matches.append(key)
            }
        }
        if Task.isCancelled { return nil }
        guard column != nil else {
            return matches.sorted { a, b in
                if a.isFolder != b.isFolder { return a.isFolder }
                let cmp = a.name.localizedStandardCompare(b.name)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return Self.isBeforeByPath(a, b)
            }
        }
        return matches.sorted(by: isBefore)
    }

    private func isBefore(_ a: ArchiveItemKey, _ b: ArchiveItemKey) -> Bool {
        switch column {
        case ArchiveSortOrder.name.rawValue:
            if a.isFolder != b.isFolder {
                return a.isFolder
            }

            let cmp = a.name.localizedStandardCompare(b.name)
            if cmp != .orderedSame {
                return ascending ? cmp == .orderedAscending : cmp == .orderedDescending
            }

        case ArchiveSortOrder.modificationDate.rawValue:
            let lhs = a.modificationDate ?? .distantPast
            let rhs = b.modificationDate ?? .distantPast

            if lhs != rhs {
                return ascending ? lhs < rhs : lhs > rhs
            }

        case ArchiveSortOrder.uncompressedSize.rawValue:
            if a.uncompressedSize != b.uncompressedSize {
                return ascending
                ? a.uncompressedSize < b.uncompressedSize
                : a.uncompressedSize > b.uncompressedSize
            }

        case ArchiveSortOrder.compressedSize.rawValue:
            if a.compressedSize != b.compressedSize {
                return ascending
                ? a.compressedSize < b.compressedSize
                : a.compressedSize > b.compressedSize
            }

        case ArchiveSortOrder.posixPermissions.rawValue:
            let lhs = a.posixPermissions ?? 0
            let rhs = b.posixPermissions ?? 0

            if lhs != rhs {
                return ascending ? lhs < rhs : lhs > rhs
            }

        default:
            break
        }

        // the column above left them equal — settle it the same way every time
        return Self.isBeforeByPath(a, b)
    }

    /// Settles two entries the chosen column cannot separate. Ties are the rule,
    /// not the exception — same name in two folders, same size, same timestamp —
    /// and `sorted(by:)` is free to order equal elements any way it likes, so
    /// without this the rows reshuffle as the search set narrows.
    private static func isBeforeByPath(_ a: ArchiveItemKey, _ b: ArchiveItemKey) -> Bool {
        let cmp = a.path.localizedStandardCompare(b.path)
        if cmp != .orderedSame { return cmp == .orderedAscending }
        return a.id.uuidString < b.id.uuidString
    }
}
