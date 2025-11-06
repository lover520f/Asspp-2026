//
//  InstallerView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

#if os(iOS)
    import SwiftUI
    import UIKit

    struct InstallerView: View {
        @StateObject var installer: Installer

        private enum HostMode: String, CaseIterable, Identifiable {
            case automatic
            case manual

            var id: String { rawValue }
            var title: String {
                switch self {
                case .automatic: String(localized: "Suggested")
                case .manual: String(localized: "Manual")
                }
            }
        }

        private enum Step: Int, CaseIterable, Identifiable {
            case certificate
            case install

            var id: Int { rawValue }
            var title: String {
                switch self {
                case .certificate: String(localized: "Certificate")
                case .install: String(localized: "Install")
                }
            }
        }

        @State private var hostMode: HostMode = .automatic
        @State private var hostOptions: [InstallerHost] = []
        @State private var selectedHostID: InstallerHost.ID?
        @State private var manualHost: String = ""
        @State private var currentStep: Step = .certificate

        private var defaultHost: InstallerHost {
            InstallerHost(host: InstallerCertificates.defaultServerName, port: installer.port)
        }

        private var manualHostContext: InstallerHost? {
            let trimmed = manualHost.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return InstallerHost(host: trimmed, port: installer.port)
        }

        private var effectiveHost: InstallerHost {
            switch hostMode {
            case .automatic:
                if let id = selectedHostID,
                   let host = hostOptions.first(where: { $0.id == id })
                {
                    return host
                }
                return hostOptions.first ?? defaultHost
            case .manual:
                return manualHostContext ?? defaultHost
            }
        }

        private var certificateURLString: String {
            if let url = InstallerCertificates.caDownloadURL(for: effectiveHost) ?? InstallerCertificates.caURL {
                return url.absoluteString
            }
            return ""
        }

        private var installURLString: String {
            installer.iTunesLink(for: effectiveHost).absoluteString
        }

        private var statusIcon: String {
            switch installer.status {
            case .ready:
                return "app.gift"
            case .sendingManifest:
                return "paperplane.fill"
            case .sendingPayload:
                return "paperplane.fill"
            case .completed(.success):
                return "app.badge.checkmark"
            case .completed(.failure):
                return "exclamationmark.triangle.fill"
            case .broken:
                return "exclamationmark.triangle.fill"
            }
        }

        private var statusText: String {
            switch installer.status {
            case .ready:
                return String(localized: "Waiting for device to scan the QR code")
            case .sendingManifest:
                return String(localized: "Sending manifest…")
            case .sendingPayload:
                return String(localized: "Transferring payload…")
            case let .completed(result):
                switch result {
                case .success:
                    return String(localized: "Install completed")
                case let .failure(error):
                    return error.localizedDescription
                }
            case let .broken(error):
                return error.localizedDescription
            }
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        stepPicker
                        hostPicker
                        Divider()
                        switch currentStep {
                        case .certificate:
                            certificateStep
                        case .install:
                            installStep
                        }
                    }
                    .padding(24)
                }
                .navigationTitle(String(localized: "QR Installer"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear {
                refreshHosts()
            }
            .onDisappear {
                installer.destroy()
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentStep)
            .animation(.spring(response: 0.45, dampingFraction: 0.9), value: hostMode)
        }

        private var stepPicker: some View {
            Picker(String(localized: "Step"), selection: $currentStep) {
                ForEach(Step.allCases) { step in
                    Text(step.title).tag(step)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Text("Installer step"))
        }

        private var hostPicker: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "Select Host"))
                    .font(.headline)
                Picker(String(localized: "Mode"), selection: $hostMode) {
                    ForEach(HostMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch hostMode {
                case .automatic:
                    VStack(alignment: .leading, spacing: 8) {
                        if hostOptions.isEmpty {
                            Text(String(localized: "No network addresses detected. Make sure Wi-Fi or Ethernet is connected."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker(String(localized: "Host"), selection: Binding(
                                get: { selectedHostID ?? hostOptions.first?.id },
                                set: { selectedHostID = $0 }
                            )) {
                                ForEach(hostOptions) { host in
                                    Text(host.displayName).tag(Optional(host.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        Button {
                            refreshHosts()
                        } label: {
                            Label(String(localized: "Refresh Hosts"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                case .manual:
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(String(localized: "Hostname or IP"), text: $manualHost)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        Text(String(localized: "Enter an address reachable from the device you plan to install on."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        private var certificateStep: some View {
            VStack(spacing: 20) {
                Text(String(localized: "Step 1: Install Certificate"))
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(localized: "Scan this code with the target device to download the installer certificate, then mark it as trusted in Settings."))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                Text("\(String(localized: \"Current host\")): \(effectiveHost.host)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                QRCodeView(value: certificateURLString)
                    .frame(maxWidth: 260, maxHeight: 260)
                    .padding(16)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                VStack(alignment: .leading, spacing: 8) {
                    Text(certificateURLString)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    HStack {
                        Button {
                            openURL(string: certificateURLString)
                        } label: {
                            Label(String(localized: "Open"), systemImage: "safari")
                        }
                        Button {
                            copyToPasteboard(certificateURLString)
                        } label: {
                            Label(String(localized: "Copy"), systemImage: "doc.on.doc")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "After installing, go to Settings → General → About → Certificate Trust Settings and enable full trust for the certificate."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var installStep: some View {
            VStack(spacing: 20) {
                Text(String(localized: "Step 2: Install Application"))
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                statusBadge
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(String(localized: \"Current host\")): \(effectiveHost.host)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                QRCodeView(value: installURLString)
                    .frame(maxWidth: 260, maxHeight: 260)
                    .padding(16)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                VStack(alignment: .leading, spacing: 8) {
                    Text(installURLString)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    HStack {
                        Button {
                            openURL(string: installURLString)
                        } label: {
                            Label(String(localized: "Open"), systemImage: "safari")
                        }
                        Button {
                            copyToPasteboard(installURLString)
                        } label: {
                            Label(String(localized: "Copy"), systemImage: "doc.on.doc")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Keep this screen visible while the install is in progress."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var statusBadge: some View {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .symbolVariant(.fill)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.accent)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(statusText)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }

        private func refreshHosts() {
            let hosts = installer.availableHosts()
            hostOptions = hosts
            if selectedHostID == nil {
                selectedHostID = hosts.first?.id
            } else if let selected = selectedHostID, !hosts.contains(where: { $0.id == selected }) {
                selectedHostID = hosts.first?.id
            }
        }

        private func openURL(string: String) {
            guard let url = URL(string: string) else { return }
            UIApplication.shared.open(url)
        }

        private func copyToPasteboard(_ string: String) {
            UIPasteboard.general.string = string
        }
    }
#endif
