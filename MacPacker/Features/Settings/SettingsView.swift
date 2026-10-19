//
//  PreferencesView.swift
//  MacPacker
//
//  Created by Stephan Arenswald on 02.12.23.
//

import Foundation
import SwiftUI

/// The panes of the Settings window, in sidebar order.
///
/// MacPacker Lab: the titles are English only and kept out of the string
/// catalog (`String`, not `LocalizedStringResource`).
enum SettingsViewTab: Int, CaseIterable, Identifiable {
    case general
    case archiveWindow
    case formats
    case extraction
    case integration
    case permissions
    case advanced
    case about
    case debug

    var id: Int { self.rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .archiveWindow: "Window"
        case .formats: "Formats"
        case .extraction: "Extraction"
        case .integration: "Finder"
        case .permissions: "Permissions"
        case .advanced: "Advanced"
        case .about: "About"
        case .debug: "Debug"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .archiveWindow: "macwindow"
        case .formats: "doc.zipper"
        case .extraction: "shippingbox"
        case .integration: "folder"
        case .permissions: "lock"
        case .advanced: "wrench.and.screwdriver"
        case .about: "info.circle"
        case .debug: "ant"
        }
    }

    /// The app's own drawing for the tile instead of an SF Symbol: Tabler's
    /// outline icons (MIT), as in the approved mockup — a zip file, a box with
    /// a short arrow out to the right, a lock with a keyhole, a single wrench.
    var drawing: String? {
        switch self {
        case .formats: "settings.formats"
        case .extraction: "settings.extraction"
        case .permissions: "settings.permissions"
        case .advanced: "settings.advanced"
        default: nil
        }
    }

    /// The colour of the tile behind the symbol: General grey, Advanced
    /// black, and the others the owner's "Jewel" palette — sapphire, copper,
    /// emerald, gold, ruby, amethyst — a different hue for every pane.
    var tint: Color {
        switch self {
        case .general: .gray
        case .archiveWindow: Color(hex: 0x2B5CAB)
        case .formats: Color(hex: 0xC2612A)
        case .extraction: Color(hex: 0x25865A)
        case .integration: Color(hex: 0xB68B1C)
        case .permissions: Color(hex: 0xA8323E)
        case .advanced: Color(hex: 0x111113)
        case .about: Color(hex: 0x6A4C9C)
        case .debug: .mint
        }
    }

    /// The panes above the sidebar's divider: everyday settings.
    static let main: [SettingsViewTab] = [.general, .archiveWindow, .formats, .extraction, .integration, .permissions]

    /// The panes below it.
    static var secondary: [SettingsViewTab] {
        #if DEBUG
        [.advanced, .about, .debug]
        #else
        [.advanced, .about]
        #endif
    }
}

/// Settings as a sidebar of panes, each a grouped form, the way System
/// Settings is laid out.
struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $state.selectedSettingsTab)
                // the column width alone is not honoured in the Settings window
                .frame(minWidth: 200)
                .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 200)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            // Every pane is built when the window opens and kept: switching
            // only shows another, so nothing holds up the highlight's slide
            // (building a pane, the Formats one above all, took long enough
            // to be seen).
            ZStack {
                ForEach(SettingsViewTab.main + SettingsViewTab.secondary) { tab in
                    let isShown = tab == state.selectedSettingsTab
                    pane(tab)
                        .opacity(isShown ? 1 : 0)
                        .allowsHitTesting(isShown)
                        .accessibilityHidden(!isShown)
                }
            }
            .navigationTitle(state.selectedSettingsTab.title)
        }
        .frame(width: 720, height: 560)
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    @ViewBuilder
    private func pane(_ tab: SettingsViewTab) -> some View {
        switch tab {
        case .general: GeneralSettingsView()
        case .archiveWindow: ArchiveWindowSettingsView()
        case .formats: FormatSettingsView()
        case .extraction: ExtractionSettingsView()
        case .integration: IntegrationSettingsView()
        case .permissions: PermissionsSettingsView()
        case .advanced: AdvancedSettingsView()
        case .about: AboutSettingsView()
        case .debug:
            #if DEBUG
            DebugSettingsView()
            #else
            EmptyView()
            #endif
        }
    }
}

/// The sidebar: a row per pane, with a soft highlight behind the selected one
/// that slides to the next. Its own rows rather than a `List`, whose solid
/// accent selection also tinted the tiles. The arrow keys move the selection.
private struct SettingsSidebar: View {
    @Binding var selection: SettingsViewTab
    @FocusState private var isFocused: Bool

    private static let rowHeight: CGFloat = 42
    private static let rowSpacing: CGFloat = 2
    /// The divider between the two groups, with the space around it.
    private static let dividerHeight: CGFloat = 17

    private var tabs: [SettingsViewTab] { SettingsViewTab.main + SettingsViewTab.secondary }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
                .frame(height: Self.rowHeight)
                .offset(y: highlightOffset)
                .animation(.spring(duration: 0.28, bounce: 0.12), value: selection)

            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                ForEach(SettingsViewTab.main) { row($0) }
                // exactly 1 pt, so the highlight's offset adds up
                Rectangle()
                    .fill(.separator)
                    .frame(height: 1)
                    .padding(.vertical, (Self.dividerHeight - 1) / 2)
                    .padding(.horizontal, 10)
                ForEach(SettingsViewTab.secondary) { row($0) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .frame(maxHeight: .infinity, alignment: .top)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { move(by: -1) }
        .onKeyPress(.downArrow) { move(by: 1) }
        .onAppear { isFocused = true }
    }

    /// Where the highlight sits: under the selected row, past the divider for
    /// the second group.
    private var highlightOffset: CGFloat {
        let step = Self.rowHeight + Self.rowSpacing
        if let index = SettingsViewTab.main.firstIndex(of: selection) {
            return CGFloat(index) * step
        }
        let index = SettingsViewTab.secondary.firstIndex(of: selection) ?? 0
        return CGFloat(SettingsViewTab.main.count) * step + Self.dividerHeight + Self.rowSpacing
            + CGFloat(index) * step
    }

    private func row(_ tab: SettingsViewTab) -> some View {
        SidebarRow(tab: tab, height: Self.rowHeight, isSelected: selection == tab) {
            selection = tab
            // so the arrow keys go on from here, after a click elsewhere
            isFocused = true
        }
    }

    private func move(by step: Int) -> KeyPress.Result {
        guard let index = tabs.firstIndex(of: selection),
              tabs.indices.contains(index + step) else { return .ignored }
        selection = tabs[index + step]
        return .handled
    }
}

/// A row of the sidebar. A press — a click, a tap on the trackpad, or the
/// keyboard and accessibility — selects the pane and plays a short pulse, a
/// shrink and a spring back, that runs to its end however brief the press.
private struct SidebarRow: View {
    let tab: SettingsViewTab
    let height: CGFloat
    let isSelected: Bool
    let select: () -> Void

    /// Each new value plays the pulse once.
    @State private var pulses = 0
    /// The pointer is down on the row: its press has been handled.
    @State private var isPressing = false
    /// The button's action that follows a pointer press is that same press.
    @State private var pressHandledByPointer = false

    var body: some View {
        Button {
            // The keyboard and accessibility have no pointer press before.
            if pressHandledByPointer {
                pressHandledByPointer = false
            } else {
                press()
            }
        } label: {
            HStack(spacing: 10) {
                SettingsIcon(tab: tab)
                Text(tab.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(height: height)
            .contentShape(Rectangle())
            .keyframeAnimator(initialValue: 1.0, trigger: pulses) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                CubicKeyframe(0.95, duration: 0.08)
                SpringKeyframe(1.0, duration: 0.3, spring: .snappy)
            }
        }
        .buttonStyle(SidebarRowButtonStyle())
        // as the mouse button or the trackpad goes down, as sidebars select,
        // rather than as it comes up
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressing else { return }
                    isPressing = true
                    pressHandledByPointer = true
                    press()
                }
                .onEnded { _ in isPressing = false }
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func press() {
        select()
        pulses += 1
    }
}

/// No press look of its own: the plain style's dimming made rows flicker as
/// they were clicked, and the pulse shows the press instead.
private struct SidebarRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// A pane's symbol, white and centred on a tile of the pane's colour.
private struct SettingsIcon: View {
    let tab: SettingsViewTab

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(tab.tint)
            .frame(width: 30, height: 30)
            .overlay {
                // a black tile would melt into a dark sidebar without an edge
                if tab == .advanced {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                }
            }
            .overlay {
                Group {
                    if let drawing = tab.drawing {
                        Image(drawing)
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 15, weight: .medium))
                    }
                }
                .foregroundStyle(.white)
            }
    }
}

/// A setting's row: its name (and what it does) on the left, its control on
/// the right, centred on the whole row. A `Form` lines controls up with the
/// title's first line instead, which looked wrong beside a second line.
struct SettingRow<Control: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingLabel(title: title, detail: detail)
            Spacer(minLength: 8)
            control
        }
    }
}

/// A setting that is on or off, as a switch on a centred row.
struct SettingToggle: View {
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        SettingRow(title: title, detail: detail) {
            Toggle(isOn: $isOn) { Text(title) }
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

/// A setting's name with, when it needs one, a line saying what it does.
struct SettingLabel: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SettingsView()
}

private extension Color {
    /// A colour from its 0xRRGGBB value.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
