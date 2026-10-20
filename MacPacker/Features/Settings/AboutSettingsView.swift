//
//  AboutSettingsView.swift
//  MacPacker
//
//  Created by Stephan Arenswald on 12.04.26.
//

import SwiftUI

/// MacPacker Lab: the About pane, centred — the app, its version and links,
/// the legal notice as the maker wrote it, and the legal links at the foot.
struct AboutSettingsView: View {
    @AppStorage("checkForUpdates") var checkForUpdates: SettingUpdateCheck = .automatically
    @AppStorage("updateBetaChannelOn") var updateBetaChannelOn: Bool = false

    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState

    var body: some View {
        // At least as tall as the pane, so the links sit at its foot; taller
        // (the website build's update and donation rows) scrolls.
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Image(nsImage: .appIcon(size: 128))
                .resizable()
                .frame(width: 96, height: 96)

            Text(Bundle.main.displayName)
                .font(.title2.weight(.medium))
                .padding(.top, 8)
            Text(.labSettingsVersion(Bundle.main.appVersionLong, Bundle.main.appBuild))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 2)

            HStack {
                #if !STORE
                if let updaterController = appState.updaterController {
                    CheckForUpdatesView(updater: updaterController.updater)
                }
                #endif
                Button {
                    openURL(Constants.changelogURL)
                } label: {
                    Text(.labSettingsWhatsNew)
                }
                Button {
                    openURL(Constants.homepageURL)
                } label: {
                    Text(.commonWebsite)
                }
                Button {
                    openURL(URL(string: "mailto:\(Constants.supportMail)")!)
                } label: {
                    Text(.contact)
                }
            }
            .padding(.top, 16)

            #if !STORE
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: Binding(
                    get: { checkForUpdates == .automatically },
                    set: { checkForUpdates = $0 ? .automatically : .manually }
                )) {
                    Text(.settingsAutomaticallyCheckForUpdates)
                }
                Toggle(.settingsIncludeBetaUpdates, isOn: $updateBetaChannelOn)
                    .disabled(checkForUpdates == .manually)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .padding(.top, 14)
            #endif

            VStack(spacing: 4) {
                Text(verbatim: "© 2023-2026 Stephan Arenswald")
                Text(verbatim: "Licensed under the GNU General Public License v3.0 (GPL-3.0-or-later). This is free software: you can redistribute it and/or modify it under the terms of the GPL.")
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: "No warranty. See LICENSE for details.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 400)
            .padding(.top, 20)

            #if !STORE
            VStack(spacing: 8) {
                Text(.feedbackSupport)
                    .fontWeight(.semibold)
                HStack {
                    Image("BuyMeCoffee")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 32)
                        .onTapGesture {
                            openURL(URL(string: "https://www.buymeacoffee.com/sarensw")!)
                        }
                    Image("Paypal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 32)
                        .onTapGesture {
                            openURL(URL(string: "https://www.paypal.com/donate/?hosted_button_id=KM8GA7MJMYNQN")!)
                        }
                }
            }
            .padding(.top, 16)
            #endif

            Spacer(minLength: 24)

            HStack(spacing: 18) {
                footerLink(Text(.commonAcknowledgements)) { AckWindowController().show() }
                footerLink(Text(.commonPrivacy)) { openURL(Constants.privacyURL) }
                footerLink(Text(.commonTerms)) { openURL(Constants.termsURL) }
                footerLink(Text(.commonImprint)) { openURL(Constants.imprintURL) }
            }
        }
        .padding(.top, 36)
        .padding(.bottom, 20)
        .padding(.horizontal, 24)
    }

    private func footerLink(_ label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AboutSettingsView()
}
