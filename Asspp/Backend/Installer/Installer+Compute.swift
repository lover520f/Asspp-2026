//
//  Installer+Compute.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import Foundation

extension Installer {
    var plistPath: String { "/\(id).plist" }

    var payloadPath: String { "/\(id).ipa" }

    var displayImageSmallPath: String { "/app57x57.png" }

    var displayImageLargePath: String { "/app512x512.png" }

    func plistEndpoint(for host: InstallerHost) -> URL {
        host.httpsURL(path: plistPath)
    }

    func payloadEndpoint(for host: InstallerHost) -> URL {
        host.httpsURL(path: payloadPath)
    }

    func iTunesLink(for host: InstallerHost) -> URL {
        let manifestURL = plistEndpoint(for: host)
        var comps = URLComponents()
        comps.scheme = "itms-services"
        comps.path = "/"
        comps.queryItems = [
            URLQueryItem(name: "action", value: "download-manifest"),
            URLQueryItem(name: "url", value: manifestURL.absoluteString),
        ]
        return comps.url!
    }

    func displayImageSmallEndpoint(for host: InstallerHost) -> URL {
        host.httpsURL(path: displayImageSmallPath)
    }

    var displayImageSmallData: Data {
        createWhite(57)
    }

    func displayImageLargeEndpoint(for host: InstallerHost) -> URL {
        host.httpsURL(path: displayImageLargePath)
    }

    var displayImageLargeData: Data {
        createWhite(512)
    }

    func indexHTML(for host: InstallerHost) -> String {
        """
        <html> <head> <meta http-equiv="refresh" content="0;url=\(iTunesLink(for: host).absoluteString)"> </head> </html>
        """
    }

    func installManifest(for host: InstallerHost) -> [String: Any] {
        [
            "items": [
                [
                    "assets": [
                        [
                            "kind": "software-package",
                            "url": payloadEndpoint(for: host).absoluteString,
                        ],
                        [
                            "kind": "display-image",
                            "url": displayImageSmallEndpoint(for: host).absoluteString,
                        ],
                        [
                            "kind": "full-size-image",
                            "url": displayImageLargeEndpoint(for: host).absoluteString,
                        ],
                    ],
                    "metadata": [
                        "bundle-identifier": archive.software.bundleID,
                        "bundle-version": archive.software.version,
                        "kind": "software",
                        "title": archive.software.name,
                    ],
                ],
            ],
        ]
    }

    func installManifestData(for host: InstallerHost) -> Data {
        (try? PropertyListSerialization.data(
            fromPropertyList: installManifest(for: host),
            format: .xml,
            options: .zero
        )) ?? .init()
    }

    func availableHosts() -> [InstallerHost] {
        InstallerHostResolver.availableHosts(port: port)
    }
}
