//
//  DefaultArchiveApp.swift
//  MacPacker
//
//  MacPacker Lab: makes this app the one that opens archives, from Settings ▸
//  Formats, without the Get Info "Change All…" trick.
//

import AppKit
import Core
import UniformTypeIdentifiers

/// Which app opens each archive format, and handing formats to this app or
/// back to the app they had before.
///
/// macOS keeps a default app per file type (`UTType`), not per format, and the
/// type it gives an extension is not always the one the catalog lists: `.lzh`
/// is `public.archive.lha`, not `org.7-zip.lha-archive`. So a format is handled
/// through the type of each of its extensions, the one Finder goes by when a
/// file is double-clicked.
@MainActor
enum DefaultArchiveApp {
    /// Formats the one-click button leaves to the apps that usually open them:
    /// installers and programs (pkg, msi, exe) and help files (chm). Each can
    /// still be ticked on its own in the table.
    static let leftOutOfOneClick: Set<String> = ["msapp", "msi", "pkg", "chm"]
    /// Kinds the one-click button leaves alone: disk images, which mount.
    static let kindsLeftOutOfOneClick: Set<String> = ["image"]
    /// Extensions this app never takes: files that are zips or rars inside but
    /// belong to other apps (Java, Android, comic readers), and `.aar`, which
    /// macOS knows as Apple Archive rather than Android's.
    static let otherAppsExtensions: Set<String> = ["jar", "apk", "aar", "cbz", "cbr"]

    /// For each file type this app took over, the bundle ID of the app that
    /// opened it before, to give it back to.
    private static let previousAppsKey = "defaultArchiveAppPrevious"

    /// The file types of a format's extensions as macOS knows them, with the
    /// short tarball names (`.tgz`) for a compression format.
    static func types(of format: ArchiveTypeDto, in catalog: ArchiveTypeCatalog) -> [UTType] {
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

    /// The formats the one-click button covers: archives and compressed files.
    static func isInOneClick(_ format: ArchiveTypeDto) -> Bool {
        !kindsLeftOutOfOneClick.contains(format.kind) && !leftOutOfOneClick.contains(format.id)
    }

    /// How many of the types another app opens now, and those apps' names:
    /// macOS may ask the user to confirm taking each of these types over.
    static func otherApps(opening types: [UTType]) -> (typeCount: Int, names: [String]) {
        var typeCount = 0
        var names: [String] = []
        for type in types {
            guard let app = NSWorkspace.shared.urlForApplication(toOpen: type),
                  Bundle(url: app)?.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
            typeCount += 1
            let name = app.deletingPathExtension().lastPathComponent
            if !names.contains(name) {
                names.append(name)
            }
        }
        return (typeCount, names)
    }

    /// Whether this app opens every one of the types.
    static func opensAll(_ types: [UTType]) -> Bool {
        !types.isEmpty && types.allSatisfy(opens)
    }

    private static func opens(_ type: UTType) -> Bool {
        bundleID(ofAppOpening: type) == Bundle.main.bundleIdentifier
    }

    private static func bundleID(ofAppOpening type: UTType) -> String? {
        NSWorkspace.shared.urlForApplication(toOpen: type).flatMap { Bundle(url: $0)?.bundleIdentifier }
    }

    /// Makes this app open the types, noting for each the app it takes over
    /// from. macOS asks the user itself for a type that needs their consent.
    static func take(_ types: [UTType]) async -> [Error] {
        var previous = previousApps
        var errors: [Error] = []
        for type in types where !opens(type) {
            let before = bundleID(ofAppOpening: type)
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type)
                if let before {
                    previous[type.identifier] = before
                }
            } catch {
                errors.append(error)
            }
        }
        previousApps = previous
        return errors
    }

    /// Gives each type back to the app that opened it before this app took it
    /// over or, when that app is unknown or gone, to the app macOS ranks next.
    /// A type nothing else opens stays with this app: macOS can't unset one.
    static func giveBack(_ types: [UTType]) async -> [Error] {
        var previous = previousApps
        var errors: [Error] = []
        for type in types where opens(type) {
            let before = previous[type.identifier]
                .flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            let next = NSWorkspace.shared.urlsForApplications(toOpen: type)
                .first { Bundle(url: $0)?.bundleIdentifier != Bundle.main.bundleIdentifier }
            guard let app = before ?? next else { continue }
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type)
                previous[type.identifier] = nil
            } catch {
                errors.append(error)
            }
        }
        previousApps = previous
        return errors
    }

    private static var previousApps: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: previousAppsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: previousAppsKey) }
    }
}
