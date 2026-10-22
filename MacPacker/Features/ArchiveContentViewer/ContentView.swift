//
//  ContentView.swift
//  MacPacker
//
//  Created by Stephan Arenswald on 01.08.23.
//

import AppKit
import Core
import SwiftUI

struct ContentView: View {
    // settings
    @AppStorage(Keys.settingBreadcrumbPosition) var breadcrumbPosition: BreadcrumbPosition = .bottom
    
    // environment
    @Environment(\.openWindow) var openWindow
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject var archiveState: ArchiveState
    
    @State private var showPasswordSheet: Bool = false
    @State private var passwordContinuation: CheckedContinuation<String?, Never>?
    /// The request the sheet is currently answering, so it can name the archive
    /// and say that the previous attempt was rejected.
    @State private var passwordRequest: ArchivePasswordRequest?

    var body: some View {
        VStack(spacing: 0) {
            if breadcrumbPosition == .top {
                if let selectedItem = archiveState.selectedItem {
                    BreadcrumbView(for: selectedItem)
                }
                
                Divider()
                    .frame(height: 1)
                    .background(.quinary)
            }
            
            ArchiveView()
            
            if breadcrumbPosition == .bottom {
                if let selectedItem = archiveState.selectedItem {
                    Divider()
                        .frame(height: 1)
                        .background(.quinary)
                    
                    BreadcrumbView(for: selectedItem)
                }
            }
            
            // the window's own extractions, rather than in another window
            if let windowID = archiveState.windowID {
                WindowExtractionProgressView(center: archiveState.progressCenter, window: windowID)
            }

            Divider()
                .frame(height: 1)
                .background(.quinary)
            
            StatusBarView(progressCenter: archiveState.progressCenter)
        }
        .toolbar {
            ArchiveContentToolbarView(
                archiveState: archiveState
            )
        }
        .searchable(text: Binding(
            get: { archiveState.searchText },
            set: { archiveState.search($0) }
        ))
        .onAppear {
            // MacPacker Lab: -OpenSettings
            if LaunchParameters.takeOpenSettings() {
                SettingsTiming.begin()
                openSettings()
            }
            if self.archiveState.passwordProvider == nil {
                let passwordProvider: ArchivePasswordUserProvider = { request in

                    await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            self.passwordContinuation = continuation
                            self.passwordRequest = request
                            self.showPasswordSheet = true
                        }
                    }
                }
                
                self.archiveState.passwordProvider = passwordProvider
            }
        }
        // A failed open ends in reset(), so the window falls back to its empty
        // state: without this the user's drag or double-click just appears to do
        // nothing. Extraction failures are deliberately not shown here — the
        // window's progress strip, or the progress window, already reports those.
        .alert(
            .errorOpenArchive,
            isPresented: Binding(
                get: { archiveState.openError != nil },
                set: { presented in
                    if !presented { archiveState.clearOpenError() }
                }
            ),
            presenting: archiveState.openError
        ) { _ in
            Button(.commonOk, role: .cancel) { }
        } message: { reason in
            Text(verbatim: reason)
        }
        // A failed or refused save has no other surface either: the status bar
        // just stops, and the window looks saved.
        .alert(
            Text(.errorSaveFailed),
            isPresented: Binding(
                get: { archiveState.saveError != nil },
                set: { presented in
                    if !presented { archiveState.clearSaveError() }
                }
            ),
            presenting: archiveState.saveError
        ) { _ in
            Button(.commonOk, role: .cancel) { }
        } message: { reason in
            Text(verbatim: reason)
        }
        // MacPacker Lab: what "Test archive" found. A test that was stopped
        // says nothing.
        .alert(
            Text(archiveState.testResult?.isIntact == false
                 ? LocalizedStringResource.archiveTestFailed
                 : .archiveTestPassed),
            isPresented: Binding(
                get: { archiveState.testResult != nil },
                set: { presented in
                    if !presented { archiveState.clearTestResult() }
                }
            ),
            presenting: archiveState.testResult
        ) { _ in
            Button(.commonOk, role: .cancel) { }
        } message: { result in
            Text(verbatim: Self.message(for: result))
        }
        .sheet(isPresented: $showPasswordSheet) {
            PasswordView(
                request: passwordRequest,
                onSubmit: { password in
                    passwordContinuation?.resume(returning: password)
                    passwordContinuation = nil
                    showPasswordSheet = false
                },
                onCancel: {
                    passwordContinuation?.resume(returning: nil)
                    passwordContinuation = nil
                    showPasswordSheet = false
                }
            )
            .frame(width: 366)
        }
        .navigationTitle(archiveState.hasArchive == false ? Bundle.main.displayName : archiveState.name!)
        .navigationSubtitle(Text(verbatim: "\(archiveState.diff.count > 0 ? String(localized: .archiveBrowseEdited) + " • " : "")\(archiveState.url == nil ? "" : archiveState.url!.deletingLastPathComponent().path + "/")"))
        .environmentObject(archiveState)
    }

    /// The reason a test gave, as the engine gave it, and the first of the
    /// files it named.
    private static func message(for result: ArchiveTestResult) -> String {
        guard let problem = result.problem else {
            return String(localized: .archiveTestPassedMessage(result.archiveName))
        }
        var lines = [String(localized: .archiveTestFailedMessage(result.archiveName)), "", problem]
        if !result.damagedPaths.isEmpty {
            lines += ["", String(localized: .archiveTestDamagedFiles)]
            lines += result.damagedPaths.prefix(10)
            if result.damagedPaths.count > 10 { lines.append("…") }
        }
        return lines.joined(separator: "\n")
    }
}

