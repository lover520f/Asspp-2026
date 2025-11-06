//
//  Installer+TLS.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import Foundation
import NIOCore
import NIOSSL
import Vapor

extension Installer {
    static let sni = InstallerCertificates.defaultServerName

    static func setupTLS() throws -> TLSConfiguration {
        let defaultBundle = try InstallerCertificates.certificateBundle(for: InstallerCertificates.defaultServerName)

        var configuration = TLSConfiguration.makeServerConfiguration(
            certificateChain: defaultBundle.chain.map { .certificate($0) },
            privateKey: .privateKey(defaultBundle.privateKey)
        )

        configuration.sslContextCallback = { values, promise in
            let requestedHost = values.serverHostname
            do {
                let bundle = try InstallerCertificates.certificateBundle(for: requestedHost)
                var override = NIOSSLContextConfigurationOverride()
                override.certificateChain = bundle.chain.map { .certificate($0) }
                override.privateKey = .privateKey(bundle.privateKey)
                promise.succeed(override)
            } catch {
                promise.fail(error)
            }
        }

        return configuration
    }
}
