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

        /// One file of a compressed tar as macOS's tar extracts it, byte for byte.
        private static func tarBytes(_ archive: URL, _ name: String) throws -> Data {
            let out = archive.deletingLastPathComponent().appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: out) }
            _ = try tar(["-xf", archive.path, "-C", out.path, name])
            return try Data(contentsOf: out.appendingPathComponent(name))
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

        /// 250 KB that nothing shrinks, in 64 KB volumes: the compressed file is
        /// what is cut, so the pieces joined are a plain compressed tar again.
        @MainActor @Test(arguments: [CompressionOptions.Format.tarGz, .tarXz, .tarBz2])
        func aCompressedTarSplitsIntoVolumes(format: CompressionOptions.Format) async throws {
            let dir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            let payload = noise(bytes: 250_000)
            let input = dir.appendingPathComponent("noise.bin")
            try payload.write(to: input)
            let base = dir.appendingPathComponent("split." + format.rawValue)
            let volumeSize = 64 << 10

            try SevenZipArchive.writeArchive(destination: base, items: [.addFile(archivePath: "noise.bin", diskPath: input)],
                                             options: .init(format: format, volumeSize: UInt64(volumeSize)))

            let parts = try volumes(of: base)
            let sizes = try parts.map(size(of:))
            #expect(!FileManager.default.fileExists(atPath: base.path), "only the volumes are written")
            #expect(parts.map(\.lastPathComponent) == (1...parts.count).map { "split.\(format.rawValue).\(String(format: "%03d", $0))" })
            #expect(parts.count >= 4, "\(sizes)")
            #expect(sizes.dropLast().allSatisfy { $0 == volumeSize }, "\(sizes)")
            #expect((1...volumeSize).contains(sizes.last ?? 0), "\(sizes)")

            let joined = dir.appendingPathComponent("joined." + format.rawValue)
            try Data(try parts.map { try Data(contentsOf: $0) }.joined()).write(to: joined)
            #expect(try Self.tarBytes(joined, "noise.bin") == payload, "the pieces joined, through macOS's tar")

            // the window opens the set from any volume, at its first, and shows the
            // tar's files under the set's name
            for part in [parts[0], parts[2]] {
                let state = ArchiveState(catalog: ArchiveTypeCatalog(), engineSelector: ArchiveEngineSelector7zip())
                state.folderAccessProvider = { _ in true }   // the volumes beside it take folder access
                state.open(url: part)
                try await state.openTask?.value
                #expect(state.error == nil, "\(state.error ?? "")")
                #expect(state.url?.lastPathComponent == parts[0].lastPathComponent)
                #expect(state.name == base.lastPathComponent)
                let names = state.entries.values.compactMap(\.virtualPath)
                #expect(names.contains("noise.bin"), "\(part.lastPathComponent): \(names)")
            }
        }

        /// Save As from a set of volumes writes the tar it holds again, whole.
        @Test func aSplitCompressedTarIsSavedAsAWholeOne() throws {
            let dir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            let payload = noise(bytes: 200_000)
            let base = dir.appendingPathComponent("set.tar.gz")
            try SevenZipArchive.writeArchive(destination: base, items: [.addData(archivePath: "noise.bin", data: payload)],
                                             options: .init(format: .tarGz, volumeSize: 64 << 10))
            let first = try #require(try volumes(of: base).first)

            let whole = dir.appendingPathComponent("whole.tar.xz")
            try SevenZipArchive.writeArchive(source: first, destination: whole, items: [],
                                             options: .init(format: .tarXz), rewrite: true)

            #expect(try Self.tarBytes(whole, "noise.bin") == payload)
            #expect(try volumes(of: whole).isEmpty)
        }

        /// As for a zip or a 7z: the volumes can't take the place of the archive
        /// they are written from.
        @Test func aCompressedTarIsNotSplitInPlace() throws {
            let (folder, items) = try Self.makeFiles()
            defer { try? FileManager.default.removeItem(at: folder) }
            let archive = folder.appendingPathComponent("out.tar.gz")
            try SevenZipArchive.writeArchive(destination: archive, items: items, options: .init(format: .tarGz))
            let before = try Data(contentsOf: archive)

            #expect(throws: SevenZipError.self) {
                try SevenZipArchive.writeArchive(source: archive, destination: archive, items: [],
                                                 options: .init(format: .tarGz, volumeSize: 64 << 10))
            }
            #expect(try Data(contentsOf: archive) == before)
            #expect(try volumes(of: archive).isEmpty)
        }

        /// An older set by that name is refused, and before anything is written:
        /// the tar pass alone can take long.
        @Test func anExistingSetIsLeftAloneBeforeTheTarIsMade() throws {
            let dir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            let base = dir.appendingPathComponent("set.tar.xz")
            let options = CompressionOptions(format: .tarXz, volumeSize: 64 << 10)
            try SevenZipArchive.writeArchive(destination: base, items: [.addData(archivePath: "first.bin", data: noise(bytes: 150_000))],
                                             options: options)
            let before = try volumes(of: base).map { try Data(contentsOf: $0) }
            let reports = Reports()

            do {
                try SevenZipArchive.writeArchive(destination: base, items: [.addData(archivePath: "second.bin", data: noise(bytes: 10_000))],
                                                 options: options) { done, total in
                    reports.all.append((done, total))
                    return true
                }
                Issue.record("wrote over an existing set of volumes")
            } catch SevenZipError.writeFailed(let message) {
                #expect(message.contains("set.tar.xz.001 already exists"), "\(message)")
            }
            #expect(try volumes(of: base).map { try Data(contentsOf: $0) } == before, "the old set is untouched")
            #expect(reports.all.isEmpty, "refused before the tar pass began")
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

        @Test func aCompressedTarOffersNeitherStoreNorPasswordNorMethods() {
            let options = options()
            options.format = .tarXz
            #expect(options.levels == [1, 3, 5, 7, 9])
            #expect(!options.canEncrypt)
            #expect(options.volumeSizes == CompressionOptions.volumeSizes, "split like a zip or a 7z")
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
        }

        @Test func storeBecomesTheDefaultLevelForATar() {
            let options = options()
            options.format = .zip
            options.level = 0
            options.format = .tarBz2
            #expect(options.level == 5)
        }
    }

    /// MacPacker Lab: a tar.gz, tar.xz or tar.bz2 window is edited as a zip
    /// or a 7z one is — what is written is a compressed tar again, of the same
    /// compression, and Save As to another format takes the tar's files.
    @MainActor
    struct CompressedTarEditingTests {
        /// The format 7-Zip names the compression around the tar by.
        private static func compression(of format: CompressionOptions.Format) -> String {
            switch format {
            case .tarGz: "gzip"
            case .tarXz: "xz"
            default: "bzip2"
            }
        }

        private func makeState(reading: ZipReader = .sevenZip) -> ArchiveState {
            let selector: any ArchiveEngineSelectorProtocol =
                reading == .xad ? ArchiveEngineSelectorXad() : ArchiveEngineSelector7zip()
            let state = ArchiveState(catalog: ArchiveTypeCatalog(), engineSelector: selector)
            state.folderAccessProvider = { _ in true }
            return state
        }

        /// `a.txt`, `docs/` and `docs/b.txt`, written as `name`.
        private func compressedTar(_ name: String, _ format: CompressionOptions.Format, in dir: URL) throws -> URL {
            let docs = dir.appendingPathComponent("src/docs", isDirectory: true)
            try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            let a = dir.appendingPathComponent("src/a.txt")
            let b = docs.appendingPathComponent("b.txt")
            try Data("hello".utf8).write(to: a)
            try Data("world".utf8).write(to: b)
            let archive = dir.appendingPathComponent(name)
            try SevenZipArchive.writeArchive(destination: archive, items: [
                .addFile(archivePath: "a.txt", diskPath: a),
                .addDirectory(archivePath: "docs", diskPath: docs),
                .addFile(archivePath: "docs/b.txt", diskPath: b),
            ], options: .init(format: format))
            return archive
        }

        /// What macOS's tar lists, directories without their slash.
        private func listed(_ archive: URL) throws -> Set<String> {
            Set(try systemTar(["-tf", archive.path]).split(separator: "\n").map {
                $0.hasSuffix("/") ? String($0.dropLast()) : String($0)
            })
        }

        @Test(arguments: [CompressionOptions.Format.tarGz, .tarXz, .tarBz2])
        func aCompressedTarIsEditedAndSavedInPlace(_ format: CompressionOptions.Format) async throws {
            let dir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            let archive = try compressedTar("out." + format.rawValue, format, in: dir)
            let state = makeState()
            state.open(url: archive)
            try await state.openTask?.value
            #expect(state.canBeEdited)
            #expect(state.writtenCompressedTar == format, "what Save As starts from")

            state.remove(items: [try #require(state.entries.values.first { $0.virtualPath == "a.txt" })])
            let added = dir.appendingPathComponent("c.txt")
            try Data("added".utf8).write(to: added)
            #expect(await state.add(url: added).value)
            await state.save()?.value

            #expect(state.saveError == nil, "\(state.saveError ?? "")")
            #expect(try listed(archive) == ["docs", "docs/b.txt", "c.txt"])
            #expect(try SevenZipArchive(url: archive).formatName?.lowercased() == Self.compression(of: format))
            #expect(state.entries.values.contains { $0.virtualPath == "c.txt" }, "the window shows what was saved")
            #expect(state.canBeEdited, "and can still be edited")
        }

        /// The compression is the archive's, not the name's: a `.tgz` is
        /// written as a gzip again, not as whatever a `tgz` name would make.
        @Test func aShortNamedCompressedTarKeepsItsCompression() async throws {
            let dir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            let written = try compressedTar("out.tar.gz", .tarGz, in: dir)
            let archive = dir.appendingPathComponent("out.tgz")
            try FileManager.default.moveItem(at: written, to: archive)
            let state = makeState()
            state.open(url: archive)
            try await state.openTask?.value
            state.remove(items: [try #require(state.entries.values.first { $0.virtualPath == "a.txt" })])
            await state.save()?.value

            #expect(state.saveError == nil, "\(state.saveError ?? "")")
            #expect(try SevenZipArchive(url: archive).formatName?.lowercased() == "gzip")
            #expect(try listed(archive) == ["docs", "docs/b.txt"])
        }

        /// Save As to a zip takes the files in the tar — not the tar as one file.
        @Test(arguments: [CompressionOptions.Format.zip, .sevenZ])
        func aCompressedTarIsSavedAsAnotherFormatWithItsFiles(_ target: CompressionOptions.Format) async throws {
            let dir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            let state = makeState()
            state.open(url: try compressedTar("out.tar.xz", .tarXz, in: dir))
            try await state.openTask?.value
            let copy = dir.appendingPathComponent("copy." + target.rawValue)
            await state.save(to: copy, options: .init(format: target))?.value

            #expect(state.saveError == nil, "\(state.saveError ?? "")")
            let files = try SevenZipArchive(url: copy).entries.filter { !$0.isDirectory }.map(\.path)
            #expect(Set(files).isSuperset(of: ["a.txt", "docs/b.txt"]), "\(files)")
            #expect(!files.contains("out.tar"), "\(files)")
        }

        /// As for a zip or a 7z set: no Save over the first volume, Save As as usual.
        @Test func aSplitCompressedTarIsSavedElsewhereOnly() async throws {
            let dir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            let base = dir.appendingPathComponent("set.tar.gz")
            try SevenZipArchive.writeArchive(destination: base, items: [
                .addData(archivePath: "noise.bin", data: noise(bytes: 150_000)),
                .addData(archivePath: "note.txt", data: Data("note".utf8)),
            ], options: .init(format: .tarGz, volumeSize: 64 << 10))
            let parts = try volumes(of: base)
            let before = try parts.map { try Data(contentsOf: $0) }
            let state = makeState()
            state.open(url: parts[0])
            try await state.openTask?.value
            #expect(state.canBeEdited)
            #expect(state.writtenCompressedTar == .tarGz, "a set's name ends in `001`")

            state.remove(items: [try #require(state.entries.values.first { $0.virtualPath == "note.txt" })])
            await state.save()?.value
            #expect(state.saveError?.contains("split into volumes") == true, "\(state.saveError ?? "saved")")
            #expect(try volumes(of: base).map { try Data(contentsOf: $0) } == before)

            let whole = dir.appendingPathComponent("whole.tar.gz")
            await state.save(to: whole, options: .init(format: .tarGz))?.value
            #expect(state.saveError == nil, "\(state.saveError ?? "")")
            #expect(try listed(whole) == ["noise.bin"])
        }

        /// A plain tar has no writer here, and a tar.gz XAD listed has XAD's
        /// numbers for its entries, which 7-Zip's writer would take for others.
        @Test func aPlainTarAndOneXADReadStayReadOnly() async throws {
            let dir = try makeTempDir()
            defer { try? FileManager.default.removeItem(at: dir) }
            let gz = try compressedTar("out.tar.gz", .tarGz, in: dir)
            let tar = dir.appendingPathComponent("plain.tar")
            try systemTar(["-cf", tar.path, "-C", dir.appendingPathComponent("src").path, "a.txt"])

            let plain = makeState()
            plain.open(url: tar)
            try await plain.openTask?.value
            #expect(plain.hasArchive && !plain.canBeEdited)

            let xad = makeState(reading: .xad)
            xad.open(url: gz)
            try await xad.openTask?.value
            #expect(xad.hasArchive && !xad.canBeEdited)
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
