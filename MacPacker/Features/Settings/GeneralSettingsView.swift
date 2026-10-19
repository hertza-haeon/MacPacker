//
//  SettingsGeneralView.swift
//  MacPacker
//
//  Created by Stephan Arenswald on 02.12.23.
//

import Core
import Foundation
import SwiftUI

/// MacPacker Lab: the app's windows, its menu bar item and its history. The
/// archive window and extraction have panes of their own.
struct GeneralSettingsView: View {
    @AppStorage(Keys.quitOnLastWindowClosed) var quitOnLastWindowClosed: Bool = false
    @AppStorage(Keys.openArchivesInTabs) var openArchivesInTabs: Bool = true
    @AppStorage(Keys.showMenuBarItem) var showMenuBarItem: Bool = false
    @AppStorage(Keys.rememberRecentArchives) var rememberRecentArchives: Bool = true

    var body: some View {
        Form {
            Section {
                SettingToggle(title: "Open archives in tabs", isOn: $openArchivesInTabs)
                SettingToggle(title: "Quit when the last window closes", isOn: $quitOnLastWindowClosed)
            } header: {
                Text(verbatim: "Windows")
            }

            Section {
                SettingToggle(title: "Show in menu bar", isOn: $showMenuBarItem)
            } header: {
                Text(verbatim: "Menu Bar")
            }

            Section {
                SettingToggle(title: "Remember recent archives",
                              detail: "Turning this off clears the list.",
                              isOn: $rememberRecentArchives)
            } header: {
                Text(verbatim: "History")
            }
        }
        .formStyle(.grouped)
        // Turning it off is a privacy switch, so what was collected goes with it —
        // the start page's "Clear" is out of reach once the section is hidden.
        .onChange(of: rememberRecentArchives) { _, isOn in
            if !isOn { RecentArchives.clear() }
        }
    }
}

#Preview {
    GeneralSettingsView()
}
