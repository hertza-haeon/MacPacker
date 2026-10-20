//
//  LabStringCatalogTests.swift
//  Modules
//
//  MacPacker Lab: every string the Lab adds to the app's catalog is there in
//  each language the catalog has, with the same arguments as in English, and
//  with the comment a translator would go by.
//

import Foundation
import Testing

extension AllCoreTests {
    struct LabStringCatalogTests {
        /// The keys the Lab's own strings go by.
        static let labPrefixes = ["lab", "accessibility", "notification", "archiveTest", "commonTest", "archiveNameEncoding"]

        private struct Catalog: Decodable {
            struct Entry: Decodable {
                struct Localization: Decodable {
                    struct Unit: Decodable { let state: String; let value: String }
                    let stringUnit: Unit?
                }
                let comment: String?
                let extractionState: String?
                let localizations: [String: Localization]?
            }
            let strings: [String: Entry]
        }

        private static func catalog() throws -> Catalog {
            let file = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .appending(path: "MacPacker/Localizable.xcstrings")
            return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: file))
        }

        /// `%@`, `%lld` and their numbered forms, in no particular order: a
        /// language may put them in its own.
        private static func arguments(_ text: String) -> [String] {
            text.matches(of: /%(\d\$)?(lld|@)/).map { String($0.output.0) }.sorted()
        }

        @Test func everyLabStringIsInEveryLanguage() throws {
            let catalog = try Self.catalog()
            let languages = Set(catalog.strings.values.flatMap { $0.localizations?.keys ?? [:].keys })
            #expect(languages.count == 21)

            let lab = catalog.strings.filter { key, _ in Self.labPrefixes.contains { key.hasPrefix($0) } }
            #expect(lab.count > 100)
            for (key, entry) in lab {
                #expect(entry.extractionState == "manual", "\(key)")
                #expect(entry.comment?.isEmpty == false, "\(key)")
                let english = try #require(entry.localizations?["en"]?.stringUnit?.value, "\(key)")
                for language in languages {
                    let unit = entry.localizations?[language]?.stringUnit
                    #expect(unit?.state == "translated", "\(key) \(language)")
                    #expect(unit?.value.isEmpty == false, "\(key) \(language)")
                    #expect(Self.arguments(unit?.value ?? "") == Self.arguments(english), "\(key) \(language)")
                }
            }
        }
    }
}
