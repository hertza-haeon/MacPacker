//
//  SettingsGeneralView.swift
//  MacPacker
//
//  Created by Stephan Arenswald on 02.12.23.
//

import Core
import Foundation
import SwiftUI

/// MacPacker Lab: the app's windows, its menu bar item, its notifications and
/// its history. The archive window and extraction have panes of their own.
struct GeneralSettingsView: View {
    @AppStorage(Keys.quitOnLastWindowClosed) var quitOnLastWindowClosed: Bool = false
    @AppStorage(Keys.openArchivesInTabs) var openArchivesInTabs: Bool = true
    @AppStorage(Keys.showMenuBarItem) var showMenuBarItem: Bool = false
    @AppStorage(Keys.rememberRecentArchives) var rememberRecentArchives: Bool = true
    @AppStorage(Keys.notifyFinishedJobs) var notifyFinishedJobs: Bool = true
    @AppStorage(Keys.notifyFinishedJobsAfter) var notifyFinishedJobsAfter: Int = FinishedJobNotices.defaultDuration

    var body: some View {
        Form {
            Section {
                SettingToggle(title: .labSettingsOpenInTabs, isOn: $openArchivesInTabs)
                SettingToggle(title: .labSettingsQuitOnLastWindow, isOn: $quitOnLastWindowClosed)
            } header: {
                Text(.labSettingsSectionWindows)
            }

            Section {
                SettingToggle(title: .labSettingsShowInMenuBar, isOn: $showMenuBarItem)
            } header: {
                Text(.labSettingsSectionMenuBar)
            }

            Section {
                SettingToggle(title: .labSettingsNotifyFinishedJobs, isOn: $notifyFinishedJobs)
                // only means something when the one above is on
                Picker(selection: $notifyFinishedJobsAfter) {
                    ForEach(FinishedJobNotices.durationChoices, id: \.self) { seconds in
                        Text(Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
                            .tag(seconds)
                    }
                } label: {
                    SettingLabel(title: .labSettingsNotifyAfter)
                }
                // the label above is a view of its own, which leaves the menu
                // unnamed for VoiceOver
                .accessibilityLabel(Text(.labSettingsNotifyAfter))
                .padding(.leading, 20)
                .disabled(!notifyFinishedJobs)
            } header: {
                Text(.labSettingsSectionNotifications)
            }

            Section {
                SettingToggle(title: .labSettingsRememberRecent,
                              detail: .labSettingsRememberRecentDetail,
                              isOn: $rememberRecentArchives)
            } header: {
                Text(.labSettingsSectionHistory)
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
