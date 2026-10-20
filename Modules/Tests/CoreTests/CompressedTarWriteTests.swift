//
//  CompressedTarWriteTests.swift
//  Modules
//
//  MacPacker Lab: tar.gz, tar.xz and tar.bz2, written in two passes — a tar,
//  then that compressed — and read back by macOS's own tar, which is what most
//  people will open them with.
//

import Foundation
import Swift7zip
import Testing
@testable import Core

extension AllCoreTests {
    struct CompressedTarWriteTests {
        /// A folder of its own for each test, and what goes in the archive.
        private static func makeFiles() throws -> (folder: URL, items: [ArchiveUpdateItem]) {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder.appendingPathComponent("docs"), withIntermediateDirectories: true)
            let a = folder.appendingPathComponent("a.txt")
            let b = folder.appendingPathComponent("docs/b.txt")
            try Data("hello".utf8).write(to: a)
            try Data(String(repeating: "world ", count: 10_000).utf8).write(to: b)
            return (folder, [
                .addFile(archivePath: "a.txt", diskPath: a),
                .addDirectory(archivePath: "docs", diskPath: folder.appendingPathComponent("docs")),
                .addFile(archivePath: "docs/b.txt", diskPath: b),
            ])
        }

        /// Runs macOS's tar and gives back what it printed.
        private static func tar(_ arguments: [String]) throws -> String {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = arguments
            let output = Pipe()
            process.standardOutput = output
            process.standardError = Pipe()
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            try #require(process.terminationStatus == 0, "tar \(arguments.joined(separator: " ")) failed")
            return String(decoding: data, as: UTF8.self)
        }

        @Test(arguments: [CompressionOptions.Format.tarGz, .tarXz, .tarBz2])
        func aCompressedTarIsReadByMacOSsTar(format: CompressionOptions.Format) throws {
            let (folder, items) = try Self.makeFiles()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = folder.appendingPathComponent("out." + format.rawValue)

            try SevenZipArchive.writeArchive(destination: archive, items: items, options: .init(format: format, level: 5))

            let listed = try Self.tar(["-tf", archive.path]).split(separator: "\n").map(String.init)
            #expect(Set(listed.map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }) == ["a.txt", "docs", "docs/b.txt"])
            #expect(try Self.tar(["-xOf", archive.path, "a.txt"]) == "hello")
            // compressed, not a tar under a compressed name
            let size = try #require(try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            #expect(size < 60_000 / 4, "\(size) bytes")
        }

        /// The panel offers no Store for a compressed tar; given one anyway, the
        /// writer compresses at the lightest level rather than fail.
        @Test(arguments: [CompressionOptions.Format.tarGz, .tarXz, .tarBz2])
        func levelZeroStillWritesACompressedTar(format: CompressionOptions.Format) throws {
            let (folder, items) = try Self.makeFiles()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = folder.appendingPathComponent("out." + format.rawValue)
            try SevenZipArchive.writeArchive(destination: archive, items: items, options: .init(format: format, level: 0))
            #expect(try Self.tar(["-xOf", archive.path, "a.txt"]) == "hello")
        }

        @Test(arguments: [CompressionOptions.Format.tarGz, .tarXz, .tarBz2])
        func aCompressedTarTakesNoPassword(format: CompressionOptions.Format) throws {
            let (folder, items) = try Self.makeFiles()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = folder.appendingPathComponent("out." + format.rawValue)

            #expect(throws: SevenZipError.self) {
                try SevenZipArchive.writeArchive(destination: archive, items: items,
                                                 options: .init(format: format, password: "secret"))
            }
            #expect(!FileManager.default.fileExists(atPath: archive.path))
        }

        @Test func theProgressOfBothPassesReachesTheWhole() throws {
            let (folder, items) = try Self.makeFiles()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = folder.appendingPathComponent("out.tar.gz")
            let reports = Reports()

            try SevenZipArchive.writeArchive(destination: archive, items: items, options: .init(format: .tarGz)) { done, total in
                reports.all.append((done, total))
                return true
            }

            let last = try #require(reports.all.last)
            #expect(last.0 == last.1, "\(last)")
            #expect(reports.all.allSatisfy { $0.0 <= $0.1 })
        }

        /// What a write reported, in order: both passes report on the writing thread.
        private final class Reports {
            var all: [(UInt64, UInt64)] = []
        }
    }

    @MainActor
    struct CompressedTarOptionsTests {
        private func options() -> ArchiveSaveOptions {
            ArchiveSaveOptions(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        }

        @Test func aCompressedTarOffersNeitherStoreNorPasswordNorVolumesNorMethods() {
            let options = options()
            options.format = .tarXz
            #expect(options.levels == [1, 3, 5, 7, 9])
            #expect(!options.canEncrypt)
            #expect(options.volumeSizes.isEmpty)
            #expect(options.methods.isEmpty)
            #expect(options.dictionarySizes.isEmpty)
            #expect(options.wordSizes.isEmpty)
        }

        @Test func aPasswordTypedForAZipDoesNotReachATar() throws {
            let options = options()
            options.format = .zip
            options.password = "secret"
            options.passwordConfirmation = "other"
            options.format = .tarGz
            #expect(options.passwordProblem == nil, "not asked for")
            let written = try #require(options.compressionOptions)
            #expect(written.password == nil)
            #expect(written.volumeSize == nil)
        }

        @Test func storeBecomesTheDefaultLevelForATar() {
            let options = options()
            options.format = .zip
            options.level = 0
            options.format = .tarBz2
            #expect(options.level == 5)
        }
    }

    struct CompressedTarNameTests {
        @Test(arguments: [
            ("photos.tar.gz", "photos"),
            ("photos.TAR.XZ", "photos"),
            ("photos.tar.bz2", "photos"),
            ("photos.zip", "photos"),
            ("photos.7z", "photos"),
            ("photos.gz", "photos"),
            ("photos", "photos"),
            ("my.photos.tar.gz", "my.photos"),
        ])
        func theWholeFormatExtensionGoes(name: String, base: String) {
            #expect(CompressionOptions.Format.baseName(of: name) == base)
        }

        @Test func aTakenCompressedTarNameGetsItsNumberBeforeTheWholeExtension() throws {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            try Data().write(to: folder.appendingPathComponent("photos.tar.gz"))

            let next = CompressDestination.unique(named: "photos.tar.gz", in: folder)
            #expect(next.lastPathComponent == "photos 2.tar.gz")
        }
    }
}
