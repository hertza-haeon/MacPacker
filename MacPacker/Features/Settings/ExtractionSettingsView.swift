//
//  ExtractionSettingsView.swift
//  MacPacker
//
//  MacPacker Lab: where an extraction goes, whether it gets a folder of its
//  own, and what becomes of the archive afterwards.
//

import Core
import SwiftUI

struct ExtractionSettingsView: View {
    @AppStorage(Keys.smartExtraction, store: .macPackerShared) var smartExtraction: Bool = true
    @AppStorage(Keys.extractNextToArchive, store: .macPackerShared) var extractNextToArchive: Bool = false
    @AppStorage(Keys.extractOnOpen) var extractOnOpen: Bool = false
    @AppStorage(Keys.closeWindowAfterExtraction) var closeWindowAfterExtraction: Bool = false
    @AppStorage(Keys.trashArchiveAfterExtraction) var trashArchiveAfterExtraction: Bool = false

    var body: some View {
        Form {
            Section {
                SettingToggle(title: .settingsExtractOnOpen, isOn: $extractOnOpen)
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
            } header: {
                Text(.labSettingsSectionContents)
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
