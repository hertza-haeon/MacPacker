//
//  AdvancedSettingsView.swift
//  MacPacker
//
//  Created by Stephan Arenswald on 17.06.25.
//

import Foundation
import SwiftUI
import tb

/// MacPacker Lab: the cache, and the logs for a bug report.
struct AdvancedSettingsView: View {
    private let applicationSupportDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first

    var body: some View {
        Form {
            Section {
                SettingRow(title: .labSettingsCacheFolder,
                           detail: .labSettingsCacheFolderDetail) {
                    HStack(spacing: 6) {
                        Button {
                            if let url = applicationSupportDirectory {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                            }
                        } label: {
                            Text(.labSettingsShowInFinder)
                        }
                        .help(.settingsShowApplicationSupportFolder)

                        Button {
                            CacheCleaner().clean()
                        } label: {
                            Text(.labSettingsClear)
                        }
                        .help(.settingsClearCacheHint)
                    }
                    .disabled(applicationSupportDirectory == nil)
                }
            } header: {
                Text(.labSettingsSectionCache)
            }

            Section {
                SettingRow(title: .labSettingsLogs, detail: .labSettingsLogsDetail) {
                    Button {
                        exportLogs()
                    } label: {
                        Text(.labSettingsExport)
                    }
                }
            } header: {
                Text(.labSettingsSectionTroubleshooting)
            }
        }
        .formStyle(.grouped)
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MacPacker-logs.ndjson"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try tb.exportRecentLogs(since: Date(timeIntervalSinceNow: -60 * 60), to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: .errorExportFailed)
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
