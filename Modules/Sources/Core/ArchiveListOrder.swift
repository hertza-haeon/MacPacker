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

    /// A folder's items in that order, as their places in `keys`; without
    /// one, as the archive lists them. Places rather than the keys
    /// themselves: a sort moves what it sorts, and a key is large.
    func sortedIndices(_ keys: [ArchiveItemKey]) -> [Int] {
        guard column != nil else { return Array(keys.indices) }
        return presorted(keys).sorted { isBefore(keys[$0], keys[$1]) }
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
            let byName = ArchiveListOrder(column: ArchiveSortOrder.name.rawValue, ascending: true)
            return byName.presorted(matches).sorted { a, b in
                let a = matches[a], b = matches[b]
                if a.isFolder != b.isFolder { return a.isFolder }
                let cmp = a.name.localizedStandardCompare(b.name)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return Self.isBeforeByPath(a, b)
            }.map { matches[$0] }
        }
        return sortedIndices(matches).map { matches[$0] }
    }

    // MARK: Presorting

    /// Below this many items, sorting is quick enough as it is.
    private static let presortAbove = 1_000

    /// `keys` in about the order `isBefore` gives, reached with byte and
    /// integer comparisons instead of `localizedStandardCompare`, which costs
    /// half a microsecond a call: sorting 100,000 names took 0.7 s. The exact
    /// sort that follows decides the order, and does little work on input
    /// that is already nearly in it — Swift's sort finds the runs.
    private func presorted(_ keys: [ArchiveItemKey]) -> [Int] {
        guard keys.count > Self.presortAbove else { return Array(keys.indices) }
        let byName = column == ArchiveSortOrder.name.rawValue
        let width = Self.longestDigitRun(keys.lazy.map { byName ? $0.name : $0.path })
        var ranks = keys.indices.map { index -> Rank in
            let key = keys[index]
            let first: UInt64
            switch column {
            case ArchiveSortOrder.name.rawValue:
                first = key.isFolder ? 0 : 1
            case ArchiveSortOrder.modificationDate.rawValue:
                first = Self.ordered((key.modificationDate ?? .distantPast).timeIntervalSinceReferenceDate)
            case ArchiveSortOrder.uncompressedSize.rawValue:
                first = Self.ordered(key.uncompressedSize)
            case ArchiveSortOrder.compressedSize.rawValue:
                first = Self.ordered(key.compressedSize)
            case ArchiveSortOrder.posixPermissions.rawValue:
                first = Self.ordered(key.posixPermissions ?? 0)
            default:
                first = 0
            }
            // the name orders a name column; the path settles the others
            let bytes = Self.sortBytes(byName ? key.name : key.path, digitWidth: width)
            // descending: the column reversed, folders still first
            let reversed = !ascending
            return Rank(
                first: reversed && !byName ? ~first : first,
                bytes: bytes,
                reversed: reversed && byName,
                index: index)
        }
        ranks.sort(by: Rank.precedes)
        return ranks.map(\.index)
    }

    /// An item's place by the column's value, then by its name or path as
    /// bytes, the first sixteen of them read as two integers.
    private struct Rank {
        let first: UInt64
        let head0: UInt64
        let head1: UInt64
        let bytes: [UInt8]
        let reversed: Bool
        let index: Int

        init(first: UInt64, bytes: [UInt8], reversed: Bool, index: Int) {
            self.first = first
            self.bytes = bytes
            self.reversed = reversed
            self.index = index
            head0 = Self.integer(bytes, from: 0)
            head1 = Self.integer(bytes, from: 8)
        }

        private static func integer(_ bytes: [UInt8], from start: Int) -> UInt64 {
            var value: UInt64 = 0
            for offset in start..<(start + 8) {
                value = value << 8 | UInt64(offset < bytes.count ? bytes[offset] : 0)
            }
            return value
        }

        static func precedes(_ a: Rank, _ b: Rank) -> Bool {
            if a.first != b.first { return a.first < b.first }
            let before: Bool
            if a.head0 != b.head0 {
                before = a.head0 < b.head0
            } else if a.head1 != b.head1 {
                before = a.head1 < b.head1
            } else {
                let order = a.bytes.withUnsafeBufferPointer { pa in
                    b.bytes.withUnsafeBufferPointer { pb in
                        let common = min(pa.count, pb.count)
                        let compared = common == 0 ? 0 : memcmp(pa.baseAddress!, pb.baseAddress!, common)
                        return compared != 0 ? Int(compared) : pa.count - pb.count
                    }
                }
                if order == 0 { return a.index < b.index }
                before = order < 0
            }
            return a.reversed ? !before : before
        }
    }

    /// A name as bytes that order about as `localizedStandardCompare` does:
    /// without case, accents or width, and each run of digits padded to the
    /// same length so that numbers order by value — "file 9" before
    /// "file 10".
    private static func sortBytes(_ text: String, digitWidth: Int) -> [UInt8] {
        // ASCII, as most names are, folds by lowering its letters; the rest
        // goes through Foundation, at ten times the cost
        let folded = text.utf8.allSatisfy { $0 < 0x80 }
            ? text
            : text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(folded.utf8.count + 8)
        var digits: [UInt8] = []
        func flushDigits() {
            guard !digits.isEmpty else { return }
            var start = 0
            while start < digits.count - 1, digits[start] == UInt8(ascii: "0") { start += 1 }
            let significant = digits.count - start
            bytes.append(contentsOf: repeatElement(UInt8(ascii: "0"), count: max(0, digitWidth - significant)))
            bytes.append(contentsOf: digits[start...])
            digits.removeAll(keepingCapacity: true)
        }
        for byte in folded.utf8 {
            if byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") {
                digits.append(byte)
            } else {
                flushDigits()
                bytes.append(byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z") ? byte | 0x20 : byte)
            }
        }
        flushDigits()
        return bytes
    }

    /// The longest run of digits in any of the texts, which every run is
    /// padded to; at most 20, as many as a 64-bit number has.
    private static func longestDigitRun<S: Sequence<String>>(_ texts: S) -> Int {
        var longest = 0
        for text in texts {
            var run = 0
            for byte in text.utf8 {
                if byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") {
                    run += 1
                    longest = max(longest, run)
                } else {
                    run = 0
                }
            }
        }
        return min(longest, 20)
    }

    /// A number as an integer that keeps its order.
    private static func ordered(_ value: Int) -> UInt64 {
        UInt64(bitPattern: Int64(value)) ^ (1 << 63)
    }

    private static func ordered(_ value: Double) -> UInt64 {
        let bits = value.bitPattern
        return value.sign == .minus ? ~bits : bits | (1 << 63)
    }

    func isBefore(_ a: ArchiveItemKey, _ b: ArchiveItemKey) -> Bool {
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
    static func isBeforeByPath(_ a: ArchiveItemKey, _ b: ArchiveItemKey) -> Bool {
        let cmp = a.path.localizedStandardCompare(b.path)
        if cmp != .orderedSame { return cmp == .orderedAscending }
        return a.id.uuidString < b.id.uuidString
    }
}
