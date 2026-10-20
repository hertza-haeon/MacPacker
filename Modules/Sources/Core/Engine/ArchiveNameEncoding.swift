//
//  ArchiveNameEncoding.swift
//  Modules
//
//  MacPacker Lab: the encoding the user chose for an archive's file names.
//  A zip made on Windows stores its names in the code page of the machine
//  that made it, and says nothing about which; read as UTF-8 they come out
//  wrong. The choice is the user's, made from the names they see.
//

import CoreFoundation
import Foundation

public enum ArchiveNameEncoding {
    /// The encoding the engines read names in; `nil`, each reads them as it
    /// does by itself. Carried by the task rather than through every call:
    /// engines are made afresh for each call, and set by
    /// `NameEncodingEngine` around each.
    @TaskLocal public static var current: String.Encoding?

    /// What the menu offers besides UTF-8, which is what `nil` reads in: the
    /// DOS and Windows code pages archives are made in, one per script.
    public static let offered: [String.Encoding] = [
        encoding(.dosLatinUS),          // 437, DOS and the zip default
        encoding(.dosLatin1),           // 850
        .windowsCP1252,
        .windowsCP1250,
        encoding(.dosRussian),          // 866
        .windowsCP1251,
        .windowsCP1253,
        .windowsCP1254,
        encoding(.windowsHebrew),       // 1255
        encoding(.windowsArabic),       // 1256
        encoding(.dosThai),             // 874
        encoding(.windowsVietnamese),   // 1258
        encoding(.dosJapanese),         // 932, Shift JIS as Windows has it
        encoding(.GB_18030_2000),       // GBK and what extends it
        encoding(.dosChineseTrad),      // 950, Big 5 as Windows has it
        encoding(.dosKorean),           // 949
    ]

    private static func encoding(_ encoding: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(encoding.rawValue)))
    }
}

/// MacPacker Lab: an engine that reads names in `encoding` — the engine it
/// wraps, with `ArchiveNameEncoding.current` set around every call.
struct NameEncodingEngine: ArchiveEngine {
    let base: any ArchiveEngine
    let encoding: String.Encoding

    func statusStream() async -> AsyncStream<EngineStatus> {
        await base.statusStream()
    }

    func cancel() async {
        await base.cancel()
    }

    func loadArchive(
        url: URL,
        passwordResolver: @escaping ArchivePasswordResolver
    ) async throws -> ArchiveEngineLoadResult {
        try await ArchiveNameEncoding.$current.withValue(encoding) {
            try await base.loadArchive(url: url, passwordResolver: passwordResolver)
        }
    }

    func extract(
        items: [ArchiveItem],
        from url: URL,
        to destination: URL,
        passwordResolver: @escaping ArchivePasswordResolver
    ) async throws -> ArchiveExtractionResult {
        try await ArchiveNameEncoding.$current.withValue(encoding) {
            try await base.extract(items: items, from: url, to: destination, passwordResolver: passwordResolver)
        }
    }

    func extract(
        item: ArchiveItem,
        from url: URL,
        to destination: URL,
        passwordResolver: @escaping ArchivePasswordResolver
    ) async throws -> URL {
        try await ArchiveNameEncoding.$current.withValue(encoding) {
            try await base.extract(item: item, from: url, to: destination, passwordResolver: passwordResolver)
        }
    }

    func extract(
        _ url: URL,
        to destination: URL,
        passwordResolver: @escaping ArchivePasswordResolver
    ) async throws {
        try await ArchiveNameEncoding.$current.withValue(encoding) {
            try await base.extract(url, to: destination, passwordResolver: passwordResolver)
        }
    }

    func extract(
        items: [ArchiveItem],
        from url: URL,
        to destination: URL,
        passwordResolver: @escaping ArchivePasswordResolver,
        onProgress: ArchiveExtractionProgress?
    ) async throws -> ArchiveExtractionResult {
        try await ArchiveNameEncoding.$current.withValue(encoding) {
            try await base.extract(
                items: items, from: url, to: destination,
                passwordResolver: passwordResolver, onProgress: onProgress)
        }
    }

    func extract(
        _ url: URL,
        to destination: URL,
        passwordResolver: @escaping ArchivePasswordResolver,
        onProgress: ArchiveExtractionProgress?
    ) async throws {
        try await ArchiveNameEncoding.$current.withValue(encoding) {
            try await base.extract(url, to: destination, passwordResolver: passwordResolver, onProgress: onProgress)
        }
    }

    func test(
        _ url: URL,
        passwordResolver: @escaping ArchivePasswordResolver,
        onProgress: ArchiveExtractionProgress?
    ) async throws -> ArchiveTestReport {
        try await ArchiveNameEncoding.$current.withValue(encoding) {
            try await base.test(url, passwordResolver: passwordResolver, onProgress: onProgress)
        }
    }
}

/// MacPacker Lab: hands out the engines `base` does, reading names in
/// `encoding`.
struct NameEncodingEngineSelector: ArchiveEngineSelectorProtocol {
    let base: any ArchiveEngineSelectorProtocol
    let encoding: String.Encoding

    var allowsEngineFallback: Bool { base.allowsEngineFallback }

    func engine(for id: String) -> ArchiveEngine? {
        base.engine(for: id).map { NameEncodingEngine(base: $0, encoding: encoding) }
    }

    func engine(for type: ArchiveEngineType) -> ArchiveEngine {
        NameEncodingEngine(base: base.engine(for: type), encoding: encoding)
    }

    func engineType(for id: String) -> ArchiveEngineType? {
        base.engineType(for: id)
    }
}
