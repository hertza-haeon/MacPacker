//
//  PermissionsSettingsView.swift
//  MacPacker
//

import Core
import SwiftUI

/// MacPacker Lab: the folders the sandbox lets the app into for good.
struct PermissionsSettingsView: View {
    @State private var homeGranted = false
    @State private var volumesGranted = false

    private let home = FolderAccessStore.homeFolder
    private let volumes = FolderAccessStore.volumesFolder

    var body: some View {
        Form {
            Section {
                grantRow(
                    title: "Home folder",
                    detail: "Desktop, Documents, Downloads and the rest of your home folder.",
                    folder: home,
                    granted: homeGranted
                ) { homeGranted = true }

                grantRow(
                    title: "External volumes",
                    detail: "USB drives, memory cards and network shares.",
                    folder: volumes,
                    granted: volumesGranted
                ) { volumesGranted = true }
            } header: {
                Text(verbatim: "Folder Access")
            } footer: {
                Text(verbatim: "macOS lets \(Constants.appName) read and write only where you allow it. Allowing these two ends the folder-access questions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        // a folder granted elsewhere in the app meanwhile, as when extracting
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    @ViewBuilder
    private func grantRow(
        title: String,
        detail: String,
        folder: URL?,
        granted: Bool,
        onGranted: @escaping () -> Void
    ) -> some View {
        SettingRow(title: title, detail: detail) {
            if granted {
                Label {
                    Text(verbatim: "Allowed")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            } else {
                Button {
                    guard let folder else { return }
                    Task { @MainActor in
                        if await FolderAccessStore.shared.grantAccess(to: folder) { onGranted() }
                    }
                } label: {
                    Text(verbatim: "Allow…")
                }
                .disabled(folder == nil)
            }
        }
    }

    private func refresh() {
        let store = FolderAccessStore.shared
        homeGranted = home.map { store.hasAccess(to: $0) } ?? false
        volumesGranted = store.hasAccess(to: volumes)
    }
}

#Preview {
    PermissionsSettingsView()
}
