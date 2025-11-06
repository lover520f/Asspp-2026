//
//  InstallerCertificates.swift
//  Asspp
//
//  Created by GPT-5 Codex on 2025/11/06.
//

import Crypto
import Foundation
import NIOConcurrencyHelpers
import NIOCore
import NIOSSL
import SwiftASN1
import X509

enum InstallerCertificates {
    struct ServerCertificateBundle {
        let chain: [NIOSSLCertificate]
        let privateKey: NIOSSLPrivateKey
    }

    private struct CAContext {
        let certificate: Certificate
        let privateKey: Certificate.PrivateKey
        let niosslCertificate: NIOSSLCertificate
        let niosslPrivateKey: NIOSSLPrivateKey
        let subjectKeyIdentifier: SubjectKeyIdentifier
    }

    private static let lock = NIOLock()
    private static var cachedCA: CAContext?
    private static var cachedBundles: [String: ServerCertificateBundle] = [:]
    private static var downloadURL: URL?
    private static var caServerPort: Int?

    private static let fileManager = FileManager.default

    static let baseDirectory: URL = documentsDirectory
        .appendingPathComponent("Certificates", isDirectory: true)
    private static let caDirectory: URL = baseDirectory
    private static let hostsDirectory: URL = baseDirectory.appendingPathComponent("Hosts", isDirectory: true)

    private static let caCertificateFilename = "InstallerRootCA.pem"
    private static let caPrivateKeyFilename = "InstallerRootCA.key"

    private static let leafCertificateFilename = "leaf.pem"
    private static let leafPrivateKeyFilename = "leaf.key"

    static let defaultServerName = "asspp.local"

    static var caFileURL: URL {
        caDirectory.appendingPathComponent(caCertificateFilename, isDirectory: false)
    }

    private static var caPrivateKeyURL: URL {
        caDirectory.appendingPathComponent(caPrivateKeyFilename, isDirectory: false)
    }

    static var caURL: URL {
        lock.withLock {
            downloadURL ?? caFileURL
        }
    }

    static let caDownloadPath = "/ca.crt"

    static func bootstrap() throws {
        try lock.withLockVoid {
            try ensureDirectories()
            if cachedCA == nil {
                if fileManager.fileExists(atPath: caFileURL.path),
                   fileManager.fileExists(atPath: caPrivateKeyURL.path)
                {
                    cachedCA = try loadCAFromDisk()
                } else {
                    cachedCA = try generateCA()
                }
            }
        }
    }

    static func updateDownloadServer(port: Int) {
        lock.withLockVoid {
            caServerPort = port
            var components = URLComponents()
            components.scheme = "http"
            components.host = "localhost"
            components.port = port
            components.path = caDownloadPath
            downloadURL = components.url
        }
    }

    static func caDownloadURL(for host: InstallerHost) -> URL? {
        lock.withLock {
            guard let port = caServerPort else { return downloadURL }
            var components = URLComponents()
            components.scheme = "http"
            components.host = host.encodedHost
            components.port = port
            components.path = caDownloadPath
            return components.url
        }
    }

    static func resetDownloadURL() {
        lock.withLockVoid {
            downloadURL = nil
            caServerPort = nil
        }
    }

    static func certificateBundle(for host: String?) throws -> ServerCertificateBundle {
        try bootstrap()

        return try lock.withLock {
            let host = (host?.isEmpty == false ? host! : defaultServerName)
            let sanitizedHost = sanitize(host)

            if let cached = cachedBundles[sanitizedHost] {
                return cached
            }

            let bundle: ServerCertificateBundle
            if fileManager.fileExists(atPath: leafCertificateURL(for: sanitizedHost).path),
               fileManager.fileExists(atPath: leafPrivateKeyURL(for: sanitizedHost).path)
            {
                bundle = try loadLeafFromDisk(sanitizedHost: sanitizedHost)
            } else {
                bundle = try generateLeaf(for: host, sanitizedHost: sanitizedHost)
            }

            cachedBundles[sanitizedHost] = bundle
            return bundle
        }
    }

    static func cachedLeafHosts() -> [String] {
        lock.withLock {
            Array(cachedBundles.keys)
        }
    }

    static func flushCaches() {
        lock.withLockVoid {
            cachedBundles.removeAll()
            cachedCA = nil
        }
    }

    // MARK: - Private helpers

    private static func ensureDirectories() throws {
        if !fileManager.fileExists(atPath: caDirectory.path) {
            try fileManager.createDirectory(at: caDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: hostsDirectory.path) {
            try fileManager.createDirectory(at: hostsDirectory, withIntermediateDirectories: true)
        }
    }

    private static func loadCAFromDisk() throws -> CAContext {
        let certificatePEM = try String(contentsOf: caFileURL, encoding: .utf8)
        let certificateDocument = try PEMDocument(pemString: certificatePEM)
        let certificate = try Certificate(derEncoded: certificateDocument.derBytes)

        let privateKeyPEM = try String(contentsOf: caPrivateKeyURL, encoding: .utf8)
        let privateKey = try Certificate.PrivateKey(pemEncoded: privateKeyPEM)

        guard let niosslCertificate = try NIOSSLCertificate.fromPEMFile(caFileURL.path).first else {
            throw NSError(domain: "InstallerCertificates", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load CA certificate from disk",
            ])
        }
        let niosslPrivateKey = try NIOSSLPrivateKey(file: caPrivateKeyURL.path, format: .pem)

        let subjectKeyIdentifier = SubjectKeyIdentifier(hash: certificate.publicKey)

        return CAContext(
            certificate: certificate,
            privateKey: privateKey,
            niosslCertificate: niosslCertificate,
            niosslPrivateKey: niosslPrivateKey,
            subjectKeyIdentifier: subjectKeyIdentifier
        )
    }

    private static func generateCA() throws -> CAContext {
        let swiftKey = P256.Signing.PrivateKey()
        let privateKey = Certificate.PrivateKey(swiftKey)

        let subjectName = DistinguishedName {
            CommonName("Asspp Local Installer Root CA")
            OrganizationName("Asspp")
        }

        let now = Date()
        let notBefore = now.addingTimeInterval(-3600)
        let notAfter = now.addingTimeInterval(60 * 60 * 24 * 365 * 20)

        let subjectKeyIdentifier = SubjectKeyIdentifier(hash: privateKey.publicKey)

        let extensions = try Certificate.Extensions {
            Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
            Critical(KeyUsage(keyCertSign: true, cRLSign: true))
            subjectKeyIdentifier
        }

        let certificate = try Certificate(
            version: .v3,
            serialNumber: .init(),
            publicKey: privateKey.publicKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: subjectName,
            subject: subjectName,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: privateKey
        )

        let certificateDocument = certificate.pemRepresentation
        try certificateDocument.pemString.write(to: caFileURL, atomically: true, encoding: .utf8)

        let privateKeyDocument = try privateKey.serializeAsPEM()
        try privateKeyDocument.pemString.write(to: caPrivateKeyURL, atomically: true, encoding: .utf8)

        guard let niosslCertificate = try NIOSSLCertificate.fromPEMFile(caFileURL.path).first else {
            throw NSError(domain: "InstallerCertificates", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to materialize generated CA certificate",
            ])
        }
        let niosslPrivateKey = try NIOSSLPrivateKey(file: caPrivateKeyURL.path, format: .pem)

        return CAContext(
            certificate: certificate,
            privateKey: privateKey,
            niosslCertificate: niosslCertificate,
            niosslPrivateKey: niosslPrivateKey,
            subjectKeyIdentifier: subjectKeyIdentifier
        )
    }

    private static func loadLeafFromDisk(sanitizedHost: String) throws -> ServerCertificateBundle {
        let certificatePath = leafCertificateURL(for: sanitizedHost).path
        let privateKeyPath = leafPrivateKeyURL(for: sanitizedHost).path

        let certificates = try NIOSSLCertificate.fromPEMFile(certificatePath)
        guard let leafCertificate = certificates.first else {
            throw NSError(domain: "InstallerCertificates", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Leaf certificate chain is empty",
            ])
        }

        guard let caContext = cachedCA else {
            throw NSError(domain: "InstallerCertificates", code: -4, userInfo: [
                NSLocalizedDescriptionKey: "CA context unavailable",
            ])
        }

        let privateKey = try NIOSSLPrivateKey(file: privateKeyPath, format: .pem)

        let chain = [leafCertificate, caContext.niosslCertificate]

        return ServerCertificateBundle(chain: chain, privateKey: privateKey)
    }

    private static func generateLeaf(for host: String, sanitizedHost: String) throws -> ServerCertificateBundle {
        guard let caContext = cachedCA else {
            throw NSError(domain: "InstallerCertificates", code: -5, userInfo: [
                NSLocalizedDescriptionKey: "CA context unavailable",
            ])
        }

        let swiftKey = P256.Signing.PrivateKey()
        let leafPrivateKey = Certificate.PrivateKey(swiftKey)

        let subjectName = DistinguishedName {
            CommonName(host)
        }

        let notBefore = Date().addingTimeInterval(-3600)
        let notAfter = Date().addingTimeInterval(60 * 60 * 24 * 365)

        let authorityKeyIdentifier = AuthorityKeyIdentifier(
            keyIdentifier: caContext.subjectKeyIdentifier.keyIdentifier,
            authorityCertIssuer: [GeneralName.directoryName(caContext.certificate.subject)],
            authorityCertSerialNumber: caContext.certificate.serialNumber
        )

        let subjectKeyIdentifier = SubjectKeyIdentifier(hash: leafPrivateKey.publicKey)

        let subjectAlternativeNames = SubjectAlternativeNames(buildSubjectAlternativeNames(for: host))

        let extensions = try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            Critical(KeyUsage(digitalSignature: true, keyEncipherment: true))
            try ExtendedKeyUsage([.serverAuth])
            subjectAlternativeNames
            authorityKeyIdentifier
            subjectKeyIdentifier
        }

        let certificate = try Certificate(
            version: .v3,
            serialNumber: .init(),
            publicKey: leafPrivateKey.publicKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: caContext.certificate.subject,
            subject: subjectName,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: caContext.privateKey
        )

        let certificateDocument = certificate.pemRepresentation
        let certificateURL = leafCertificateURL(for: sanitizedHost)
        try ensureLeafContainerExists(for: sanitizedHost)
        try certificateDocument.pemString.write(to: certificateURL, atomically: true, encoding: .utf8)

        let privateKeyDocument = try leafPrivateKey.serializeAsPEM()
        let privateKeyURL = leafPrivateKeyURL(for: sanitizedHost)
        try privateKeyDocument.pemString.write(to: privateKeyURL, atomically: true, encoding: .utf8)

        let niosslLeafCertificate = try NIOSSLCertificate.fromPEMFile(certificateURL.path).first ?? {
            throw NSError(domain: "InstallerCertificates", code: -6, userInfo: [
                NSLocalizedDescriptionKey: "Failed to materialize generated leaf certificate",
            ])
        }()
        let niosslPrivateKey = try NIOSSLPrivateKey(file: privateKeyURL.path, format: .pem)

        let chain = [niosslLeafCertificate, caContext.niosslCertificate]

        return ServerCertificateBundle(chain: chain, privateKey: niosslPrivateKey)
    }

    private static func ensureLeafContainerExists(for sanitizedHost: String) throws {
        let directory = leafDirectory(for: sanitizedHost)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static func leafDirectory(for sanitizedHost: String) -> URL {
        hostsDirectory.appendingPathComponent(sanitizedHost, isDirectory: true)
    }

    private static func leafCertificateURL(for sanitizedHost: String) -> URL {
        leafDirectory(for: sanitizedHost).appendingPathComponent(leafCertificateFilename, isDirectory: false)
    }

    private static func leafPrivateKeyURL(for sanitizedHost: String) -> URL {
        leafDirectory(for: sanitizedHost).appendingPathComponent(leafPrivateKeyFilename, isDirectory: false)
    }

    private static func sanitize(_ host: String) -> String {
        let lowercase = host.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_.")
        var scalars: [Character] = []
        scalars.reserveCapacity(lowercase.count)

        for scalar in lowercase.unicodeScalars {
            if allowed.contains(scalar) {
                scalars.append(Character(scalar))
            } else {
                scalars.append("-")
            }
        }

        var sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: ".-_"))
        if sanitized.isEmpty {
            let digest = SHA256.hash(data: Data(lowercase.utf8))
            sanitized = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        }
        return sanitized
    }

    private static func buildSubjectAlternativeNames(for host: String) throws -> [GeneralName] {
        if let address = try? SocketAddress(ipAddress: host, port: 0) {
            switch address {
            case .v4(let address):
                var addr = address.address.sin_addr
                let bytes = withUnsafeBytes(of: &addr) { Array($0) }
                return [.ipAddress(ASN1OctetString(contentBytes: bytes))]
            case .v6(let address):
                var addr = address.address.sin6_addr
                let bytes = withUnsafeBytes(of: &addr) { Array($0) }
                return [.ipAddress(ASN1OctetString(contentBytes: bytes))]
            case .unixDomainSocket:
                break
            }
        }

        return [.dnsName(host)]
    }
}
