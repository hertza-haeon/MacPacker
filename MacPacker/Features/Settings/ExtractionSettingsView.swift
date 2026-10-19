//
//  ExtractionSettingsView.swift
//  MacPacker
//
//  MacPacker Lab: where an extraction goes, what it does with what it finds
//  there, and what becomes of the archive afterwards.
//

import Core
import SwiftUI

struct ExtractionSettingsView: View {
    @AppStorage(Keys.nameClash, store: .macPackerShared) var nameClash: NameClash = .keepBoth
    @AppStorage(Keys.smartExtraction, store: .macPackerShared) var smartExtraction: Bool = true
    @AppStorage(Keys.extractNextToArchive, store: .macPackerShared) var extractNextToArchive: Bool = false
    @AppStorage(Keys.closeWindowAfterExtraction) var closeWindowAfterExtraction: Bool = false
    @AppStorage(Keys.trashArchiveAfterExtraction) var trashArchiveAfterExtraction: Bool = false

    var body: some View {
        Form {
            Section {
                SettingToggle(title: "Extract next to the archive", isOn: $extractNextToArchive)
                // only means something when the one above is on
                SettingToggle(title: "Close the window afterwards", isOn: $closeWindowAfterExtraction)
                    .padding(.leading, 20)
                    .disabled(!extractNextToArchive)
            } header: {
                Text(verbatim: "Destination")
            }

            Section {
                SettingToggle(title: "Smart extraction",
                              detail: "Loose items get a folder; a single folder isn’t nested again.",
                              isOn: $smartExtraction)
                Picker(selection: $nameClash) {
                    Text(.settingsNameClashKeepBoth).tag(NameClash.keepBoth)
                    Text(.settingsNameClashReplace).tag(NameClash.replace)
                    Text(.settingsNameClashReplaceToTrash).tag(NameClash.replaceToTrash)
                } label: {
                    SettingLabel(title: "If an item already exists")
                }
            } header: {
                Text(verbatim: "Contents")
            } footer: {
                Text(verbatim: "Keep both gives the new item a number, as in “photo (2).jpg”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                SettingToggle(title: "Move the archive to the Trash",
                              detail: "After a complete extraction only, every part of a split archive included.",
                              isOn: $trashArchiveAfterExtraction)
            } header: {
                Text(verbatim: "Afterwards")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    ExtractionSettingsView()
}
