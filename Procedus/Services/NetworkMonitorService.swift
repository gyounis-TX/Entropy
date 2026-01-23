// NetworkMonitorService.swift
// Procedus - Unified
// Network connectivity monitoring for WiFi-only media uploads

import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitorService: ObservableObject {
    static let shared = NetworkMonitorService()

    // MARK: - Published Properties

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isWiFi: Bool = false
    @Published private(set) var isCellular: Bool = false
    @Published private(set) var connectionType: ConnectionType = .unknown

    // MARK: - Connection Type

    enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown = "Unknown"

        var systemImage: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "cable.connector"
            case .unknown: return "questionmark.circle"
            }
        }
    }

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - Initialization

    private init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        // NWPathMonitor.cancel() is thread-safe
        monitor.cancel()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func updateConnectionStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied

        // Check interface type
        if path.usesInterfaceType(.wifi) {
            isWiFi = true
            isCellular = false
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            isWiFi = false
            isCellular = true
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            isWiFi = false
            isCellular = false
            connectionType = .ethernet
        } else {
            isWiFi = false
            isCellular = false
            connectionType = .unknown
        }
    }

    // MARK: - Upload Permission

    /// Check if media upload is currently allowed based on network and settings
    /// - Returns: true if upload is allowed, false otherwise
    func canUploadMedia() -> Bool {
        guard isConnected else { return false }

        let allowCellular = UserDefaults.standard.bool(forKey: "allowCellularMediaUpload")

        if allowCellular {
            // Allow upload on any connection
            return true
        } else {
            // Only allow upload on WiFi (or Ethernet)
            return isWiFi || connectionType == .ethernet
        }
    }

    /// Get a human-readable reason why upload is blocked
    func uploadBlockedReason() -> String? {
        if !isConnected {
            return "No internet connection"
        }

        let allowCellular = UserDefaults.standard.bool(forKey: "allowCellularMediaUpload")
        if !allowCellular && isCellular {
            return "Waiting for WiFi (cellular upload disabled in Settings)"
        }

        return nil
    }
}

// MARK: - Combine Publisher for SwiftUI

extension NetworkMonitorService {
    /// Publisher that emits when upload availability changes
    var canUploadPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest3($isConnected, $isWiFi, $isCellular)
            .map { [weak self] _, _, _ in
                self?.canUploadMedia() ?? false
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
