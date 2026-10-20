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
                    title: .labSettingsHomeFolder,
                    detail: .labSettingsHomeFolderDetail,
                    folder: home,
                    granted: homeGranted
                ) { homeGranted = true }

                grantRow(
                    title: .labSettingsExternalVolumes,
                    detail: .labSettingsExternalVolumesDetail,
                    folder: volumes,
                    granted: volumesGranted
                ) { volumesGranted = true }
            } header: {
                Text(.labSettingsSectionFolderAccess)
            } footer: {
                Text(.labSettingsFolderAccessFooter(Constants.appName))
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
        title: LocalizedStringResource,
        detail: LocalizedStringResource,
        folder: URL?,
        granted: Bool,
        onGranted: @escaping () -> Void
    ) -> some View {
        SettingRow(title: title, detail: detail) {
            if granted {
                Label {
                    Text(.labSettingsAllowed)
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
                    Text(.labSettingsAllow)
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
