//
//  SettingsTiming.swift
//  MacPacker
//
//  MacPacker Lab: how long the Settings window takes to open, step by step,
//  in the log (category "settings"). `-OpenSettings YES` opens the window at
//  launch, so it can be timed from the request on, with nobody at the keys.
//

import Foundation
import tb

@MainActor
enum SettingsTiming {
    private static let log = tb.Logger(subsystem: "app.MacPacker", category: "settings")
    private static var start: ContinuousClock.Instant?

    /// The window was asked for: what follows is timed from here.
    static func begin() {
        start = .now
    }

    /// The window is being built; timed from here when nothing asked first,
    /// as with the Settings menu item.
    static func building() {
        if start == nil { start = .now }
    }

    static func mark(_ step: String) {
        guard let start else { return }
        let ms = (ContinuousClock.now - start) / .milliseconds(1)
        log.notice("Settings: \(step)", context: ["ms": String(format: "%.1f", ms)])
    }

    /// One step's own length, wherever the window is in opening.
    static func measure<T>(_ step: String, _ work: () -> T) -> T {
        let begin = ContinuousClock.now
        let result = work()
        let ms = (ContinuousClock.now - begin) / .milliseconds(1)
        log.notice("Settings: \(step) took", context: ["ms": String(format: "%.1f", ms)])
        return result
    }

    /// The window closed: the next opening is timed afresh.
    static func end() {
        start = nil
    }
}
