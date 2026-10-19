//
//  FormatSettingsView.swift
//  MacPacker
//
//  Created by Stephan Arenswald on 02.12.25.
//

import Core
import SwiftUI
import UniformTypeIdentifiers

struct ArchiveFormatSettings: Identifiable {
    let id: String
    let name: String
    let extensions: String
    let engines: [ArchiveEngineType]
    /// The engines that can also edit archives of this format, as the catalog
    /// says: one that only reads opens them read-only.
    let editors: Set<ArchiveEngineType>
    var selectedEngine: ArchiveEngineType
    var defaultOpen: Bool = false
    /// The file types of this format's extensions, which the default-app
    /// checkbox hands to this app or back (`DefaultArchiveApp`).
    var types: [UTType] = []
}

struct FormatSettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    @State private var rows: [ArchiveFormatSettings] = []
    @State private var selection: ArchiveFormatSettings.ID?
    
    @State private var showEngineInfo: Bool = false
    /// Mirrors the store so the toggle and the picker enablement update together.
    @State private var isAutomatic: Bool = true
    /// While formats are handed to this app or back, the checkboxes and the
    /// one-click button wait.
    @State private var isChangingDefaults = false

    fileprivate func refreshFormatConfig() {
        var result: [ArchiveFormatSettings] = []

        // Take all known formats from the catalog
        for type in appState.catalog.getAllTypes() {
            let formatId = type.id

            // Ask the store (via catalog) which engines exist for this format
            let engineOptions = appState.archiveEngineConfigStore.engineOptions(for: formatId)
            guard !engineOptions.isEmpty else {
                // No engines configured for this format – skip it
                continue
            }

            // Current engine = user override or catalog default
            guard let selectedEngine =
                    appState.archiveEngineConfigStore.selectedEngine(for: formatId) else { continue }

            let engines = engineOptions.compactMap { ArchiveEngineType(configId: $0.id) }
            let editors = Set(engineOptions.filter(\.canEdit).compactMap { ArchiveEngineType(configId: $0.id) })
            let extString = type.extensions.joined(separator: ", ")

            let types = DefaultArchiveApp.types(of: type, in: appState.catalog)

            let afs = ArchiveFormatSettings(
                id: formatId,
                name: type.name,
                extensions: extString,
                engines: engines,
                editors: editors,
                selectedEngine: selectedEngine,
                defaultOpen: DefaultArchiveApp.opensAll(types),
                types: types
            )
            result.append(afs)
        }

        result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        rows = result
    }


    /// Hands the types to this app (`take`) or back, then shows what macOS now
    /// says, and any type it refused.
    private func changeDefaults(_ types: [UTType], take: Bool) {
        isChangingDefaults = true
        Task {
            let errors = take
                ? await DefaultArchiveApp.take(types)
                : await DefaultArchiveApp.giveBack(types)
            refreshFormatConfig()
            isChangingDefaults = false
            guard !errors.isEmpty else { return }
            let alert = NSAlert()
            // MacPacker Lab: English only, kept out of the string catalog
            alert.messageText = "Some formats could not be changed"
            alert.informativeText = errors.map(\.localizedDescription).joined(separator: "\n")
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    /// Keka's one click: every archive and compressed format at once. Disk
    /// images, installers, programs and help files are left to their apps.
    ///
    /// macOS asks the user to confirm each file type it would take from an app
    /// they chose, and offers no way around it. So when other apps open some of
    /// the types now, the user is told first how many questions may follow,
    /// and can stop there.
    private func makeDefaultForArchives() {
        var seen = Set<String>()
        let types = appState.catalog.getAllTypes()
            .filter { format in DefaultArchiveApp.isInOneClick(format) && rows.contains { $0.id == format.id } }
            .flatMap { DefaultArchiveApp.types(of: $0, in: appState.catalog) }
            .filter { seen.insert($0.identifier).inserted }
        let others = DefaultArchiveApp.otherApps(opening: types)
        if others.typeCount > 0 {
            let name = Bundle.main.displayName
            let alert = NSAlert()
            // MacPacker Lab: English only, kept out of the string catalog
            alert.messageText = "Set \(name) as default?"
            alert.informativeText = others.typeCount == 1
                ? "1 of these file types opens with \(others.names.formatted(.list(type: .and))) now. macOS may ask you to confirm it, with a “Use \(name)” button."
                : "\(others.typeCount) of these file types open with \(others.names.formatted(.list(type: .and))) now. macOS may ask you to confirm each of them, one by one, with a “Use \(name)” button."
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        changeDefaults(types, take: true)
    }
    
    /// Automatic engine selection. Most people neither know nor care which
    /// engine opens their archive, so MacPacker picks — and can switch to
    /// another engine when the preferred one can't read a particular file.
    /// Turning this off hands the choice back and makes it binding.
    private var automaticBinding: Binding<Bool> {
        Binding<Bool>(
            get: { isAutomatic },
            set: { newValue in
                isAutomatic = newValue
                appState.archiveEngineConfigStore.isAutomatic = newValue
                // The Engine column shows the catalog defaults again in
                // automatic mode, so the table has to be re-read.
                refreshFormatConfig()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: automaticBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(.settingsAutomaticEngineSelection)
                    Text(.settingsAutomaticEngineSelectionHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(.bottom, 4)

            Divider()

            HStack {
                Text(.settingsDefaultStatusEngineSettings)
                Spacer()
                if isChangingDefaults {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    makeDefaultForArchives()
                } label: {
                    Text(verbatim: "Set \(Bundle.main.displayName) as default")
                }
                .disabled(isChangingDefaults)
                .help(Text(verbatim: "Opens every archive and compressed format with \(Bundle.main.displayName). Disk images, installers, programs and help files keep their apps; tick those below one by one."))
            }

            Table(rows, selection: $selection) {
                TableColumn(String("")) {
                    defaultToggle(identifier: $0.id, defaultOpen: $0.defaultOpen, types: $0.types)
                }
                .width(20)
                TableColumn(.settingsFileFormat, value: \.name)
                TableColumn(.settingsExtensions, value: \.extensions)
                TableColumn(.settingsEngine) {
                    supportedPicker(identifier: $0.id, selectedEngine: $0.selectedEngine,
                                    supportedEngines: $0.engines, editors: $0.editors)
                }
            }
            .tableStyle(.bordered)
            
            HStack {
                Button {
                    refreshFormatConfig()
                } label: {
                    Label(.commonRefresh, systemImage: "arrow.clockwise")
                }
                
                Spacer()
                
                Button {
                    showEngineInfo.toggle()
                } label: {
                    Label {
                        Text(.settingsInfoOnEngines)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.orange)
                    }

                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showEngineInfo) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(.settingsEngineChoiceHint)

                        Divider()

                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                            ForEach(ArchiveEngineType.allCases) { engine in
                                GridRow {
                                    Text(engine.rawValue)
                                    Text(engine.libraryVersion)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .font(.footnote)

                        Divider()

                        Label {
                            Text(.settingsEditsArchivesHint)
                        } icon: {
                            Image(systemName: "pencil")
                        }
                        .font(.footnote)
                    }
                    .frame(width: 260)
                    .padding()
                }
            }
        }
        .padding()
        .frame(minHeight: 400)
        .onAppear {
            isAutomatic = appState.archiveEngineConfigStore.isAutomatic

            if !rows.isEmpty {
                return
            }

            refreshFormatConfig()
        }
    }
    
    @ViewBuilder
    func defaultToggle(identifier: String, defaultOpen: Bool, types: [UTType]) -> some View {
        let binding = Binding<Bool>(
            get: { defaultOpen },
            set: { newValue in
                if let index = rows.firstIndex(where: { $0.id == identifier }) {
                    rows[index].defaultOpen = newValue
                    changeDefaults(types, take: newValue)
                }
            }
        )

        Toggle(isOn: binding, label: { Text(verbatim: "") })
            .frame(alignment: .center)
            .help(Text(verbatim: "Ticked: \(Bundle.main.displayName) opens this format. Unticked: the app that opened it before does."))
            .disabled(isChangingDefaults || types.isEmpty)
    }
    
    /// A menu takes the width of its widest engine. Every row's menu is as wide
    /// as the longest engine name at the table's small size, with room for the
    /// pencil, so they all line up.
    private static let engineMenuWidth: CGFloat = {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        let widest = ArchiveEngineType.allCases
            .map { ($0.rawValue as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        return ceil(widest) + 17   // the pencil and its spacing
    }()

    @ViewBuilder
    func supportedPicker(
        identifier: String,
        selectedEngine: ArchiveEngineType,
        supportedEngines: [ArchiveEngineType],
        editors: Set<ArchiveEngineType>
    ) -> some View {
        let binding = Binding<ArchiveEngineType>(
            get: { selectedEngine },
            set: { newValue in
                if let index = rows.firstIndex(where: { $0.id == identifier }) {
                    rows[index].selectedEngine = newValue
                    appState.archiveEngineConfigStore.setSelectedEngine(newValue, for: identifier)
                }
            }
        )

        Picker(String(""), selection: binding) {
            ForEach(supportedEngines, id: \.self) { engine in
                Group {
                    if editors.contains(engine) {
                        Label(engine.rawValue, systemImage: "pencil")
                    } else {
                        Text(engine.rawValue)
                    }
                }
                .frame(width: Self.engineMenuWidth, alignment: .leading)
                .tag(engine)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        // In automatic mode the column shows what MacPacker picked; editing it
        // would imply a choice that is not being honoured.
        .disabled(isAutomatic)
    }
}
