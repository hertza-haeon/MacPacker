//
//  ArchiveSwcEngine.swift
//  Modules
//
//  Created by Stephan Arenswald on 14.12.25.
//

import Foundation
import SWCompression
import tb

private let log = tb.Logger(subsystem: "app.MacPacker", category: "engine")

final actor ArchiveSwcEngine: ArchiveEngine {
    private var statusContinuation: AsyncStream<EngineStatus>.Continuation?

    func statusStream() -> AsyncStream<EngineStatus> {
        AsyncStream { continuation in
            self.statusContinuation = continuation
            continuation.yield(.idle)
        }
    }
    
    private func emit(_ s: EngineStatus) {
        statusContinuation?.yield(s)
    }
    
    func cancel() async {
    }
    
    private func stripFileExtension( _ filename: String ) -> String {
        var components = filename.components(separatedBy: ".")
        guard components.count > 1 else { return filename }
        components.removeLast()
        return components.joined(separator: ".")
    }
    
    func loadArchive(
        url: URL,
        passwordResolver: ArchivePasswordResolver
    ) async throws -> ArchiveEngineLoadResult {
        let name = stripFileExtension(url.lastPathComponent)
        
        emit(.done)
        
        let item = ArchiveItem(name: String(name), virtualPath: name, type: .file)
        var items: [UUID: ArchiveItem] = [:]
        items[item.id] = item
        
        return ArchiveEngineLoadResult(
            items: items,
            hasTree: false,
            uncompressedSize: 0
        )
    }
    
    func extract(
        items: [ArchiveItem],
        from url: URL,
        to destination: URL,
        passwordResolver: @escaping ArchivePasswordResolver
    ) async throws -> ArchiveExtractionResult {
        let sourceFileName = url.lastPathComponent
        let extractedFileName = stripFileExtension(sourceFileName)
        let extractedFilePathName = destination.appendingPathComponent(extractedFileName, isDirectory: false)

        // blocking decompression — keep it off the cooperative pool
        return try await runBlocking {
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
                let decompressedData = try Self.decompressed(data, of: url)

                // MacPacker Lab: a write that fails says so
                try decompressedData.write(to: extractedFilePathName, options: .atomic)

                let urlsByItemID: [UUID: URL] = [UUID(): extractedFilePathName]
                return ArchiveExtractionResult(urlsByItemID: urlsByItemID)
            }

            throw ArchiveError.extractionFailed("Swc engine: Could not decompress archive")
        }
    }
    
    func extract(
        _ url: URL,
        to destination: URL,
        passwordResolver: ArchivePasswordResolver
    ) async throws {
        let sourceFileName = url.lastPathComponent
        let extractedFileName = stripFileExtension(sourceFileName)
        let extractedFilePathName = destination.appendingPathComponent(extractedFileName, isDirectory: false)
        
        // MacPacker Lab: what fails is thrown, as every other engine does.
        // It used to be logged and left there, so a damaged archive was
        // reported extracted with nothing written — and, with "Move the
        // archive to the Trash" on, put in the Bin.
        // blocking decompression — keep it off the cooperative pool
        try await runBlocking {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                log.error("Could not read archive")
                throw ArchiveError.extractionFailed("Could not read \(url.lastPathComponent).")
            }
            let decompressedData = try Self.decompressed(data, of: url)
            try decompressedData.write(to: extractedFilePathName, options: .atomic)
        }
    }

    /// MacPacker Lab: the data decompressed, or an error that says what
    /// happened rather than SWCompression's own type name.
    private static func decompressed(_ data: Data, of url: URL) throws -> Data {
        do {
            return try LZ4.decompress(data: data)
        } catch {
            log.error(error.localizedDescription)
            throw ArchiveError.extractionFailed(
                "Could not decompress \(url.lastPathComponent): the data is damaged, or is not LZ4.")
        }
    }
}
