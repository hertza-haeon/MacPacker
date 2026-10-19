//
//  ArchiveWindowSettingsView.swift
//  MacPacker
//
//  MacPacker Lab: what the archive window shows — its columns, with a preview
//  of their header — and how it is navigated.
//

import Core
import SwiftUI
import UniformTypeIdentifiers

struct ArchiveWindowSettingsView: View {
    @AppStorage(Keys.settingBreadcrumbPosition) var breadcrumbPosition: BreadcrumbPosition = .bottom
    @AppStorage(Keys.showColumnCompressedSize) var showCompressedSize: Bool = true
    @AppStorage(Keys.showColumnUncompressedSize) var showUncompressedSize: Bool = true
    @AppStorage(Keys.showColumnModificationDate) var showModificationDate: Bool = true
    @AppStorage(Keys.showColumnPosixPermissions) var showPermissions: Bool = false
    @AppStorage(Keys.showParentRow) var showParentRow: Bool = false

    var body: some View {
        Form {
            Section {
                windowPreview
                SettingToggle(title: "Show parent folder (“..”)", isOn: $showParentRow)
                Picker(selection: $breadcrumbPosition) {
                    Text(verbatim: "Top").tag(BreadcrumbPosition.top)
                    Text(verbatim: "Bottom").tag(BreadcrumbPosition.bottom)
                    Text(verbatim: "Hidden").tag(BreadcrumbPosition.none)
                } label: {
                    SettingLabel(title: "Path bar")
                }
                .pickerStyle(.segmented)
                .fixedSize()
            } header: {
                Text(verbatim: "Preview")
            }

            Section {
                SettingToggle(title: "Packed Size", isOn: $showCompressedSize)
                SettingToggle(title: "Size", isOn: $showUncompressedSize)
                SettingToggle(title: "Date Modified", isOn: $showModificationDate)
                SettingToggle(title: "Permissions", isOn: $showPermissions)
            } header: {
                Text(verbatim: "Columns")
            }
        }
        .formStyle(.grouped)
    }

    /// A miniature archive window, as the settings here make it: the path bar
    /// above or below the list, or none; the column header, with the window's
    /// own titles in its order; the ".." row; and two files.
    private var windowPreview: some View {
        VStack(spacing: 0) {
            if breadcrumbPosition == .top {
                pathBar
                Divider()
            }
            columnHeader
            Divider()
            if showParentRow {
                fileRow(icon: NSWorkspace.shared.icon(for: .folder), name: "..", sizes: nil)
            }
            fileRow(icon: NSWorkspace.shared.icon(for: .jpeg), name: "Beach.jpg",
                    sizes: Self.values(packed: 2_150_000, size: 2_480_000, daysAgo: 8, at: (18, 4)))
            fileRow(icon: NSWorkspace.shared.icon(for: .plainText), name: "Notes.txt",
                    sizes: Self.values(packed: 900, size: 3_100, daysAgo: 17, at: (9, 12)))
            if breadcrumbPosition == .bottom {
                Divider()
                pathBar
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.separator))
        .animation(.easeOut(duration: 0.2), value: breadcrumbPosition)
        .animation(.easeOut(duration: 0.2), value: [showParentRow, showCompressedSize, showUncompressedSize,
                                                    showModificationDate, showPermissions])
    }

    /// The path bar as the window draws it: the archive, then the folder open
    /// in it.
    private var pathBar: some View {
        HStack(spacing: 4) {
            pathItem(icon: NSWorkspace.shared.icon(for: .zip), name: "Holiday.zip")
            Image(systemName: "chevron.right")
                .resizable()
                .frame(width: 3, height: 6)
                .fontWeight(.black)
                .foregroundStyle(.primary.opacity(0.6))
            pathItem(icon: NSWorkspace.shared.icon(for: .folder), name: "Photos")
            Spacer()
        }
        .font(.subheadline)
        .fontWeight(.light)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func pathItem(icon: NSImage, name: String) -> some View {
        HStack(spacing: 2) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 14, height: 14)
            Text(name)
                .lineLimit(1)
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            headerCell(String(localized: .columnName), divider: false)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showCompressedSize { headerCell(String(localized: .columnPackedSize)).frame(width: Self.packedWidth, alignment: .leading) }
            if showUncompressedSize { headerCell(String(localized: .columnSize)).frame(width: Self.sizeWidth, alignment: .leading) }
            if showModificationDate { headerCell(String(localized: .columnDateModified)).frame(width: Self.dateWidth, alignment: .leading) }
            if showPermissions { headerCell(String(localized: .columnPermissions)).frame(width: Self.permissionsWidth, alignment: .leading) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// A row of the list; `sizes` are its packed size, size, date and
    /// permissions, none for the ".." row.
    private func fileRow(icon: NSImage, name: String, sizes: (String, String, String, String)?) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(name)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            if showCompressedSize { valueCell(sizes?.0).frame(width: Self.packedWidth, alignment: .leading) }
            if showUncompressedSize { valueCell(sizes?.1).frame(width: Self.sizeWidth, alignment: .leading) }
            if showModificationDate { valueCell(sizes?.2).frame(width: Self.dateWidth, alignment: .leading) }
            if showPermissions { valueCell(sizes?.3).frame(width: Self.permissionsWidth, alignment: .leading) }
        }
        .font(.caption)
        .frame(height: 22)
    }

    private func valueCell(_ value: String?) -> some View {
        Text(value ?? "")
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
    }

    /// A sample file's columns, written as this Mac writes sizes and dates.
    private static func values(packed: Int64, size: Int64, daysAgo: Int,
                               at time: (hour: Int, minute: Int)) -> (String, String, String, String) {
        let day = Date(timeIntervalSinceNow: -Double(daysAgo) * 86_400)
        let date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) ?? day
        return (ByteCountFormatter.string(fromByteCount: packed, countStyle: .file),
                ByteCountFormatter.string(fromByteCount: size, countStyle: .file),
                date.formatted(date: .abbreviated, time: .shortened),
                "rw-r--r--")
    }

    private static let packedWidth: CGFloat = 76
    private static let sizeWidth: CGFloat = 56
    private static let dateWidth: CGFloat = 118
    private static let permissionsWidth: CGFloat = 80

    private func headerCell(_ title: String, divider: Bool = true) -> some View {
        Text(title)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                if divider { Rectangle().fill(.separator).frame(width: 1) }
            }
    }
}

#Preview {
    ArchiveWindowSettingsView()
}
