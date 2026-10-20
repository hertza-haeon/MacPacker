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
/// back to the app they had before. Which formats and types are concerned is
/// `OneClickFormats`.
@MainActor
enum DefaultArchiveApp {
    /// For each file type this app took over, the bundle ID of the app that
    /// opened it before, to give it back to.
    private static let previousAppsKey = "defaultArchiveAppPrevious"

    static func types(of format: ArchiveTypeDto, in catalog: ArchiveTypeCatalog) -> [UTType] {
        OneClickFormats.types(of: format, in: catalog)
    }

    static func isInOneClick(_ format: ArchiveTypeDto) -> Bool {
        OneClickFormats.includes(format)
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

    /// The name of the app that opens the type now, if it isn't this one.
    static func appName(opening type: UTType) -> String? {
        guard let app = NSWorkspace.shared.urlForApplication(toOpen: type),
              Bundle(url: app)?.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        return app.deletingPathExtension().lastPathComponent
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
