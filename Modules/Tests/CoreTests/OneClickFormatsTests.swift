//
//  OneClickFormatsTests.swift
//  Modules
//
//  MacPacker Lab: the one click in Settings ▸ Formats takes every archive and
//  compressed format, by the file types Finder goes by, and leaves disk
//  images, installers, programs, help files and other apps' zips alone.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Core

extension AllCoreTests {
    struct OneClickFormatsTests {
        let catalog = ArchiveTypeCatalog()

        private func format(_ id: String) throws -> ArchiveTypeDto {
            try #require(catalog.getAllTypes().first { $0.id == id })
        }

        private func type(_ fileExtension: String) throws -> UTType {
            try #require(UTType(filenameExtension: fileExtension))
        }

        @Test func everyArchiveAndCompressedFormatIsTaken() {
            for format in catalog.getAllTypes() {
                let leftOut = format.kind == "image" || ["msapp", "msi", "pkg", "chm"].contains(format.id)
                #expect(OneClickFormats.includes(format) == !leftOut, "\(format.id)")
            }
            #expect(catalog.getAllTypes().contains { $0.kind == "compression" && OneClickFormats.includes($0) })
        }

        @Test(arguments: ["dmg", "iso", "pkg", "msi", "chm"])
        func whatOpensElsewhereIsLeftOut(id: String) throws {
            #expect(!OneClickFormats.includes(try format(id)))
        }

        /// Java, Android and comic reader files are zips, and not this app's.
        @Test func aZipTakesNoneOfTheOtherAppsFiles() throws {
            let types = OneClickFormats.types(of: try format("zip"), in: catalog)
            #expect(types.contains(try type("zip")))
            for other in ["jar", "apk", "aar", "cbz"] {
                #expect(!types.contains(try type(other)), "\(other)")
            }
        }

        /// A `.tgz` is a gzip to Finder; `x.tar.gz` too, by its last extension.
        @Test func aCompressionTakesItsTarballShortNames() throws {
            let types = OneClickFormats.types(of: try format("gzip"), in: catalog)
            #expect(types.contains(try type("gz")))
            #expect(types.contains(try type("tgz")))
            #expect(!types.contains { $0.preferredFilenameExtension?.contains(".") == true })
        }

        @Test func lhaGoesByTheTypeMacOSGivesLzh() throws {
            #expect(OneClickFormats.types(of: try format("lha"), in: catalog).contains(try type("lzh")))
        }

        @Test func eachTypeIsTakenOnce() {
            for format in catalog.getAllTypes() {
                let identifiers = OneClickFormats.types(of: format, in: catalog).map(\.identifier)
                #expect(identifiers.count == Set(identifiers).count, "\(format.id)")
            }
        }
    }
}
