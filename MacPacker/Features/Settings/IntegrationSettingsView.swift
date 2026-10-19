//
//  IntegrationSettingsView.swift
//  MacPacker
//
//  Created by Stephan Arenswald on 09.01.26.
//

import FinderMenu
import FinderSync
import Foundation
import SwiftUI

/// MacPacker Lab: the Finder pane — whether the Finder extension is on, and
/// which actions its context menu offers, grouped as the menu reads.
struct IntegrationSettingsView: View {
    @State private var isFinderSyncEnabled: Bool = false

    /// The actions that open or extract; every other one compresses.
    private static let openAndExtract: [FinderMenuItem] = [.open, .extractHere, .extractToFolder, .extractToChosenFolder]
    private static let compress = FinderMenuItem.allCases.filter { !openAndExtract.contains($0) }

    /// The extension's name as System Settings lists it.
    private static let extensionName: String = {
        let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("FinderExtension.appex")
        return url.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String }
            ?? "\(Bundle.main.displayName) Finder Integration"
    }()

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.extensionName)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isFinderSyncEnabled ? Color.green : Color.secondary)
                                .frame(width: 6, height: 6)
                            Text(verbatim: isFinderSyncEnabled ? "On" : "Off")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Button {
                        FIFinderSyncController.showExtensionManagementInterface()
                    } label: {
                        Text(verbatim: "Manage…")
                    }
                }
            } header: {
                Text(verbatim: "Finder Extension")
            }

            Section {
                FinderMenuCascadedToggle()
            } header: {
                Text(verbatim: "Context Menu")
            }

            Section {
                ForEach(Self.openAndExtract, id: \.self) { FinderMenuItemToggle(item: $0) }
            } header: {
                Text(verbatim: "Open & Extract")
            }

            Section {
                ForEach(Self.compress, id: \.self) { FinderMenuItemToggle(item: $0) }
            } header: {
                Text(verbatim: "Compress")
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        // it is switched on and off in System Settings, not here
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        isFinderSyncEnabled = FIFinderSyncController.isExtensionEnabled
    }
}

/// One switch per context menu entry, stored in the app group so the Finder
/// extension — a separate process — reads the same value.
private struct FinderMenuItemToggle: View {
    private let item: FinderMenuItem
    @AppStorage private var isOn: Bool

    init(item: FinderMenuItem) {
        self.item = item
        _isOn = AppStorage(
            wrappedValue: item.isEnabledByDefault,
            FinderMenuSettings.key(for: item),
            store: FinderMenuSettings.defaults
        )
    }

    var body: some View {
        SettingToggle(title: title, isOn: $isOn)
    }

    /// Mirrors the wording of the menu entry itself, with the parts that depend
    /// on the selection written as placeholders — the same way 7-Zip lists them.
    private var title: String {
        switch item {
        case .open: "Open archive"
        case .extractHere: "Extract here"
        case .extractToFolder: "Extract to “name”"
        case .extractToChosenFolder: "Extract to…"
        case .addToArchive: "Add to archive…"
        case .compressToZip: "Compress to “name”.zip"
        case .compressTo7z: "Compress to “name”.7z"
        case .compressToDatedZip: "Compress to zip with date and time"
        case .compressEachSeparately: "Compress each item separately"
        case .compressFolderContents: "Compress a folder’s contents"
        }
    }
}

private struct FinderMenuCascadedToggle: View {
    @AppStorage(FinderMenuSettings.cascadedKey, store: FinderMenuSettings.defaults)
    private var isCascaded: Bool = true

    var body: some View {
        SettingToggle(title: "Group in a “\(Constants.appName)” submenu", isOn: $isCascaded)
    }
}

#Preview {
    IntegrationSettingsView()
}
