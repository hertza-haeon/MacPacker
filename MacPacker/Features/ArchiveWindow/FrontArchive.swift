//
//  FrontArchive.swift
//  MacPacker
//
//  MacPacker Lab: the front archive window's state, for a menu item that
//  shows it — a checkmark — rather than only acts on it. The archive windows
//  are NSWindows, out of reach of `@FocusedValue` (see `ArchiveCommands`), so
//  the window that becomes key is followed here instead.
//

import AppKit
import Combine
import Core

@MainActor
final class FrontArchive: ObservableObject {
    static let shared = FrontArchive()

    @Published private(set) var state: ArchiveState?

    private var observers: [NSObjectProtocol] = []
    private var stateChanges: AnyCancellable?

    private init() {
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.follow() }
            })
        }
        // a closed window's state is let go of, not kept for the menu
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                let closing = (note.object as? NSWindow)?.windowController as? ArchiveWindowController
                guard let self, let closing, closing.archiveState === self.state else { return }
                self.show(nil)
            }
        })
        follow()
    }

    private func follow() {
        let controller = NSApp.keyWindow?.windowController as? ArchiveWindowController
            ?? NSApp.mainWindow?.windowController as? ArchiveWindowController
        show(controller?.archiveState)
    }

    private func show(_ state: ArchiveState?) {
        guard state !== self.state else { return }
        self.state = state
        // what the menu reads of it
        stateChanges = state.map { state in
            Publishers.MergeMany([
                state.$nameEncoding.map { _ in () }.eraseToAnyPublisher(),
                state.$hasArchive.map { _ in () }.eraseToAnyPublisher(),
                state.$url.map { _ in () }.eraseToAnyPublisher(),
                state.$isBusy.map { _ in () }.eraseToAnyPublisher(),
                state.$isSaving.map { _ in () }.eraseToAnyPublisher(),
                state.$diff.map { _ in () }.eraseToAnyPublisher(),
            ])
            .sink { [weak self] in self?.objectWillChange.send() }
        }
    }
}
