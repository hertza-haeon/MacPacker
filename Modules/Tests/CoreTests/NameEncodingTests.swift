//
//  NameEncodingTests.swift
//  Modules
//
//  MacPacker Lab: names a zip stores in a Windows code page, read in the
//  encoding the user chose — in the listing, and on disk once extracted.
//  The archives are made here: a zip with ASCII names, each name's bytes
//  then changed to those of a name in that code page, as the zip made on
//  Windows would hold them.
//

import CoreFoundation
import Foundation
import Swift7zip
import Testing
@testable import Core

extension AllCoreTests {
    struct NameEncodingTests {
        static let shiftJIS = encoding(.dosJapanese)
        static let dosLatinUS = encoding(.dosLatinUS)

        private static func encoding(_ encoding: CFStringEncodings) -> String.Encoding {
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(encoding.rawValue)))
        }

        /// A zip of the given names, each stored in `encoding`, as Windows
        /// stores them: no UTF-8 flag. Names that are UTF-8 are stored as
        /// UTF-8, with the flag, as any archiver writes them.
        static func makeZip(in folder: URL, legacy: [String], encoding: String.Encoding, unicode: [String] = []) throws -> URL {
            let archive = folder.appendingPathComponent("names.zip")
            var placeholders: [(Data, Data)] = []
            var items: [ArchiveUpdateItem] = []
            for (number, name) in legacy.enumerated() {
                let bytes = try #require(name.data(using: encoding))
                let ext = ".txt"
                let stem = bytes.count - ext.utf8.count
                let placeholder = Data((String(repeating: "Q", count: stem - 1) + "\(number)" + ext).utf8)
                #expect(placeholder.count == bytes.count)
                placeholders.append((placeholder, bytes))
                items.append(.addData(archivePath: String(decoding: placeholder, as: UTF8.self), data: Data(name.utf8)))
            }
            for name in unicode {
                items.append(.addData(archivePath: name, data: Data(name.utf8)))
            }
            try SevenZipArchive.writeArchive(destination: archive, items: items, options: .init(format: .zip, level: 0))

            var zip = try Data(contentsOf: archive)
            for (placeholder, bytes) in placeholders {
                var found = 0
                while let range = zip.range(of: placeholder) {
                    zip.replaceSubrange(range, with: bytes)
                    found += 1
                }
                // the local header and the central directory
                #expect(found == 2)
            }
            try zip.write(to: archive)
            return archive
        }

        private static func makeFolder() throws -> URL {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("NameEncodingTests_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }

        /// What the names were before: private-use characters where the
        /// bytes are not UTF-8.
        @Test func unreadNamesAreNotTheNames() throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let zip = try Self.makeZip(in: folder, legacy: ["日本語.txt"], encoding: Self.shiftJIS)

            let paths = try SevenZipArchive(url: zip).entries.map(\.path)
            #expect(paths != ["日本語.txt"])
            #expect(paths.first?.unicodeScalars.contains { (0xEF80...0xEFFF).contains($0.value) } == true)
        }

        @Test(arguments: [
            (["日本語.txt", "表示.txt"], shiftJIS),
            (["café.txt", "Größe.txt"], dosLatinUS),
        ])
        func namesReadInTheChosenEncoding(names: [String], encoding: String.Encoding) throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let zip = try Self.makeZip(in: folder, legacy: names, encoding: encoding)

            let archive = try SevenZipArchive(url: zip)
            archive.setNameEncoding(encoding)
            #expect(try archive.entries.map(\.path) == names)

            let out = folder.appendingPathComponent("out", isDirectory: true)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            try archive.extractAll(to: out)
            #expect(Set(try FileManager.default.contentsOfDirectory(atPath: out.path)) == Set(names))
            #expect(try String(contentsOf: out.appendingPathComponent(names[0]), encoding: .utf8) == names[0])
        }

        /// A name stored as UTF-8 is read as UTF-8 whatever was chosen.
        @Test func aUnicodeNameStaysAsItIs() throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let zip = try Self.makeZip(in: folder, legacy: ["日本語.txt"], encoding: Self.shiftJIS, unicode: ["你好.txt", "plain.txt"])

            let archive = try SevenZipArchive(url: zip)
            archive.setNameEncoding(Self.shiftJIS)
            #expect(Set(try archive.entries.map(\.path)) == ["日本語.txt", "你好.txt", "plain.txt"])
        }

        /// One entry extracted on its own, under its name as read.
        @Test func anEntryExtractedAloneTakesItsNameAsRead() throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let zip = try Self.makeZip(in: folder, legacy: ["日本語.txt", "表示.txt"], encoding: Self.shiftJIS)

            let archive = try SevenZipArchive(url: zip)
            archive.setNameEncoding(Self.shiftJIS)
            let entry = try #require(try archive.entries.first { $0.path == "表示.txt" })
            let out = folder.appendingPathComponent("out", isDirectory: true)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let written = try archive.extract(indices: [entry.index], to: out)
            #expect(written[entry.index]?.lastPathComponent == "表示.txt")
            #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("表示.txt").path))
        }

        @Test func theXADEngineReadsNamesInTheChosenEncoding() async throws {
            let folder = try Self.makeFolder()
            defer { try? FileManager.default.removeItem(at: folder) }
            let zip = try Self.makeZip(in: folder, legacy: ["日本語.txt"], encoding: Self.shiftJIS)

            let engine = NameEncodingEngine(base: ArchiveXadEngine(), encoding: Self.shiftJIS)
            let listed = try await engine.loadArchive(url: zip, passwordResolver: { _ in nil })
            #expect(listed.items.values.map(\.name) == ["日本語.txt"])
        }

        @Test func everyOfferedEncodingIsOneMacOSKnows() {
            for encoding in ArchiveNameEncoding.offered {
                #expect(!String.localizedName(of: encoding).isEmpty, "\(encoding.rawValue)")
                #expect("a".data(using: encoding) != nil, "\(encoding.rawValue)")
            }
            #expect(Set(ArchiveNameEncoding.offered).count == ArchiveNameEncoding.offered.count)
            #expect(!ArchiveNameEncoding.offered.contains(.utf8), "what no choice reads in")
        }
    }

    @MainActor struct ArchiveStateNameEncodingTests {
        @Test func theWindowReopensWithItsNamesReadInTheChosenEncoding() async throws {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("ArchiveStateNameEncodingTests_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let zip = try NameEncodingTests.makeZip(in: folder, legacy: ["日本語.txt"], encoding: NameEncodingTests.shiftJIS)

            let state = ArchiveState(catalog: ArchiveTypeCatalog(), engineSelector: ArchiveEngineSelector7zip())
            state.progressCenter = ExtractionProgressCenter()
            state.open(url: zip)
            try await state.openTask?.value
            #expect(state.nameEncoding == nil)
            #expect(state.canBeEdited)
            #expect(!state.entries.values.contains { $0.name == "日本語.txt" })

            state.reopen(withNameEncoding: NameEncodingTests.shiftJIS)
            try await state.openTask?.value
            #expect(state.nameEncoding == NameEncodingTests.shiftJIS)
            #expect(state.entries.values.contains { $0.name == "日本語.txt" })
            // a change would name entries by names the archive does not store
            #expect(!state.canBeEdited)

            let out = folder.appendingPathComponent("out", isDirectory: true)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            #expect(await state.extract(to: out, smart: false).value == .done)
            #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("日本語.txt").path))

            // another archive opened starts over
            state.open(url: zip)
            try await state.openTask?.value
            #expect(state.nameEncoding == nil)
        }
    }
}
