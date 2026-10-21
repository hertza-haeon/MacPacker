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
                SettingToggle(title: .labSettingsExtractNextTo, isOn: $extractNextToArchive)
                // only means something when the one above is on
                SettingToggle(title: .labSettingsCloseWindowAfter, isOn: $closeWindowAfterExtraction)
                    .padding(.leading, 20)
                    .disabled(!extractNextToArchive)
            } header: {
                Text(.labSettingsSectionDestination)
            }

            Section {
                SettingToggle(title: .labSettingsSmartExtraction,
                              detail: .labSettingsSmartExtractionDetail,
                              isOn: $smartExtraction)
                Picker(selection: $nameClash) {
                    Text(.labSettingsNameClashKeepBoth).tag(NameClash.keepBoth)
                    Text(.labSettingsNameClashReplace).tag(NameClash.replace)
                    Text(.labSettingsNameClashReplaceToTrash).tag(NameClash.replaceToTrash)
                } label: {
                    SettingLabel(title: .labSettingsNameClash)
                }
                // the label above is a view of its own, which leaves the menu
                // unnamed for VoiceOver
                .accessibilityLabel(Text(.labSettingsNameClash))
            } header: {
                Text(.labSettingsSectionContents)
            } footer: {
                Text(.labSettingsNameClashFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                SettingToggle(title: .labSettingsTrashArchive,
                              detail: .labSettingsTrashArchiveDetail,
                              isOn: $trashArchiveAfterExtraction)
            } header: {
                Text(.labSettingsSectionAfterwards)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    ExtractionSettingsView()
}
