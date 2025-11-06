//
//  InstallerHost.swift
//  Asspp
//
//  Created by GPT-5 Codex on 2025/11/06.
//

import Foundation
import Vapor

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

struct InstallerHost: Identifiable, Hashable {
    let host: String
    let encodedHost: String
    let port: Int
    let interfaceName: String?
    let isLoopback: Bool
    let isIPv6: Bool

    var id: String {
        "\(encodedHost)#\(port)#\(interfaceName ?? "-")"
    }

    var displayName: String {
        if let interfaceName {
            return "\(host) (\(interfaceName))"
        }
        return host
    }

    var authority: String {
        if port == 0 {
            return encodedHost
        }
        return "\(encodedHost):\(port)"
    }

    init(host: String, port: Int, interfaceName: String? = nil, isLoopback: Bool = false, isIPv6: Bool? = nil) {
        self.host = host
        self.port = port
        self.interfaceName = interfaceName
        let resolvedIPv6 = isIPv6 ?? host.contains(":")
        self.isIPv6 = resolvedIPv6
        let loopback = isLoopback || InstallerHost.isLoopbackHost(host)
        self.isLoopback = loopback
        self.encodedHost = InstallerHost.encode(host: host)
    }

    func url(scheme: String, path: String, queryItems: [URLQueryItem]? = nil) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = encodedHost
        components.port = port
        components.path = path
        if let queryItems { components.queryItems = queryItems }
        guard let url = components.url else {
            preconditionFailure("Failed to construct URL for host: \(host), path: \(path)")
        }
        return url
    }

    func httpsURL(path: String, queryItems: [URLQueryItem]? = nil) -> URL {
        url(scheme: "https", path: path, queryItems: queryItems)
    }

    static func encode(host: String) -> String {
        if host.contains("%"), !host.contains("%25") {
            return host.replacingOccurrences(of: "%", with: "%25")
        }
        return host
    }

    static func isLoopbackHost(_ host: String) -> Bool {
        switch host {
        case "localhost", "127.0.0.1", "::1":
            return true
        default:
            return false
        }
    }
}

enum InstallerHostResolver {
    static func requestHost(from request: Request, defaultHost: String, port: Int) -> InstallerHost {
        if let header = request.headers.first(name: .host),
           let parsed = parseHostHeader(header, fallbackPort: port)
        {
            return parsed
        }

        if let urlHost = request.url.host {
            return InstallerHost(host: urlHost, port: request.url.port ?? port)
        }

        return InstallerHost(host: defaultHost, port: port)
    }

    static func availableHosts(port: Int) -> [InstallerHost] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let start = pointer else {
            return fallbackHosts(port: port)
        }
        defer { freeifaddrs(start) }

        var hosts: [InstallerHost] = []
        var seen: Set<String> = []

        var cursor: UnsafeMutablePointer<ifaddrs>? = start
        while let value = cursor {
            defer { cursor = value.pointee.ifa_next }
            guard let addressPointer = value.pointee.ifa_addr else { continue }

            let family = Int32(addressPointer.pointee.sa_family)
            if family == AF_INET {
                var address = addressPointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                if address.sin_addr.s_addr == INADDR_ANY { continue }
                let hostString = ipv4String(from: &address.sin_addr)
                if hostString.isEmpty { continue }
                if seen.insert(hostString).inserted {
                    let interface = String(cString: value.pointee.ifa_name)
                    let loopback = (value.pointee.ifa_flags & UInt32(IFF_LOOPBACK)) != 0
                    hosts.append(InstallerHost(host: hostString, port: port, interfaceName: interface, isLoopback: loopback, isIPv6: false))
                }
            } else if family == AF_INET6 {
                var address = addressPointer.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                if isZero(address.sin6_addr) { continue }
                var scopeName: String?
                if address.sin6_scope_id != 0 {
                    scopeName = String(cString: value.pointee.ifa_name)
                }
                var hostString = ipv6String(from: &address.sin6_addr)
                if hostString.isEmpty { continue }
                if let scopeName {
                    hostString += "%" + scopeName
                }
                if seen.insert(hostString).inserted {
                    let interface = String(cString: value.pointee.ifa_name)
                    let loopback = (value.pointee.ifa_flags & UInt32(IFF_LOOPBACK)) != 0 || hostString == "::1"
                    hosts.append(InstallerHost(host: hostString, port: port, interfaceName: interface, isLoopback: loopback, isIPv6: true))
                }
            }
        }

        hosts.append(contentsOf: fallbackHosts(port: port).filter { seen.insert($0.host).inserted })

        return hosts.sorted(by: { lhs, rhs in
            if lhs.isLoopback != rhs.isLoopback {
                return rhs.isLoopback // prefer non-loopback first
            }
            if lhs.isIPv6 != rhs.isIPv6 {
                return !lhs.isIPv6 // prefer IPv4
            }
            return lhs.host < rhs.host
        })
    }

    private static func fallbackHosts(port: Int) -> [InstallerHost] {
        var results: [InstallerHost] = []
        results.append(InstallerHost(host: "localhost", port: port, interfaceName: nil, isLoopback: true, isIPv6: false))
        let defaultHost = InstallerCertificates.defaultServerName
        if defaultHost != "localhost" {
            results.append(InstallerHost(host: defaultHost, port: port))
        }
        return results
    }

    private static func parseHostHeader(_ header: String, fallbackPort: Int) -> InstallerHost? {
        guard let components = URLComponents(string: "https://\(header)") else {
            return nil
        }
        guard let host = components.host else { return nil }
        let port = components.port ?? fallbackPort
        return InstallerHost(host: host, port: port)
    }

    private static func ipv4String(from address: inout in_addr) -> String {
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return ""
        }
        return String(cString: buffer)
    }

    private static func ipv6String(from address: inout in6_addr) -> String {
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard inet_ntop(AF_INET6, &address, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil else {
            return ""
        }
        return String(cString: buffer)
    }

    private static func isZero(_ address: in6_addr) -> Bool {
        withUnsafeBytes(of: address) { buffer in
            !buffer.contains { $0 != 0 }
        }
    }
}
