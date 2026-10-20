//
//  OneClickFormats.swift
//  Modules
//
//  MacPacker Lab: which formats, and which of their file types, Settings ▸
//  Formats hands to the app in one click. The app does the handing over.
//

import Foundation
import UniformTypeIdentifiers

/// macOS keeps a default app per file type (`UTType`), not per format, and the
/// type it gives an extension is not always the one the catalog lists: `.lzh`
/// is `public.archive.lha`, not `org.7-zip.lha-archive`. So a format is handled
/// through the type of each of its extensions, the one Finder goes by when a
/// file is double-clicked.
public enum OneClickFormats {
    /// Formats the one-click button leaves to the apps that usually open them:
    /// installers and programs (pkg, msi, exe) and help files (chm). Each can
    /// still be ticked on its own in the table.
    public static let leftOut: Set<String> = ["msapp", "msi", "pkg", "chm"]
    /// Kinds the one-click button leaves alone: disk images, which mount.
    public static let kindsLeftOut: Set<String> = ["image"]
    /// Extensions this app never takes: files that are zips or rars inside but
    /// belong to other apps (Java, Android, comic readers), and `.aar`, which
    /// macOS knows as Apple Archive rather than Android's.
    public static let otherAppsExtensions: Set<String> = ["jar", "apk", "aar", "cbz", "cbr"]

    /// The formats the one-click button covers: archives and compressed files.
    public static func includes(_ format: ArchiveTypeDto) -> Bool {
        !kindsLeftOut.contains(format.kind) && !leftOut.contains(format.id)
    }

    /// The file types of a format's extensions as macOS knows them, with the
    /// short tarball names (`.tgz`) for a compression format.
    public static func types(of format: ArchiveTypeDto, in catalog: ArchiveTypeCatalog) -> [UTType] {
        var extensions = format.extensions
        for compound in catalog.allCompositions() where compound.components.last == format.id {
            extensions += compound.extensions
        }
        var seen = Set<String>()
        return extensions
            // Finder goes by the last extension only: `x.tar.gz` is a `.gz`
            .filter { !$0.contains(".") && !otherAppsExtensions.contains($0.lowercased()) }
            .compactMap { UTType(filenameExtension: $0) }
            .filter { seen.insert($0.identifier).inserted }
    }
}
