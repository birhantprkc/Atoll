//
//  DoNotDisturbManager.swift
//  DynamicIsland
//
//  Replaces the legacy polling-based Focus detection with
//  NSDistributedNotificationCenter-backed monitoring.
//

import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI

final class DoNotDisturbManager: ObservableObject {
    static let shared = DoNotDisturbManager()

    @Published private(set) var isMonitoring = false
    @Published var isDoNotDisturbActive = false
    @Published var currentFocusModeName: String = ""
    @Published var currentFocusModeIdentifier: String = ""

    private let notificationCenter = DistributedNotificationCenter.default()
    private let metadataExtractionQueue = DispatchQueue(label: "com.dynamicisland.focus.metadata", qos: .userInitiated)
    private var hasLoggedPayload = false

    private init() {}

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        notificationCenter.addObserver(
            self,
            selector: #selector(handleFocusEnabled(_:)),
            name: .focusModeEnabled,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(handleFocusDisabled(_:)),
            name: .focusModeDisabled,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        notificationCenter.removeObserver(self, name: .focusModeEnabled, object: nil)
        notificationCenter.removeObserver(self, name: .focusModeDisabled, object: nil)

        isMonitoring = false

        DispatchQueue.main.async {
            self.isDoNotDisturbActive = false
            self.currentFocusModeIdentifier = ""
            self.currentFocusModeName = ""
        }
    }

    @objc private func handleFocusEnabled(_ notification: Notification) {
        apply(notification: notification, isActive: true)
    }

    @objc private func handleFocusDisabled(_ notification: Notification) {
        apply(notification: notification, isActive: false)
    }

    private func apply(notification: Notification, isActive: Bool) {
        metadataExtractionQueue.async { [weak self] in
            guard let self = self else { return }

            let metadata = self.extractMetadata(from: notification)

            DispatchQueue.main.async {
                let trimmedIdentifier = metadata.identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedName = metadata.name?.trimmingCharacters(in: .whitespacesAndNewlines)

                let incomingIdentifier = (trimmedIdentifier?.isEmpty == false ? trimmedIdentifier! : self.currentFocusModeIdentifier)
                let incomingName = (trimmedName?.isEmpty == false ? trimmedName! : self.currentFocusModeName)

                let resolvedMode = FocusModeType.resolve(identifier: incomingIdentifier, name: incomingName)

                debugPrint("[DoNotDisturbManager] Focus update -> identifier: \(trimmedIdentifier ?? "<nil>") (incoming: \(incomingIdentifier.isEmpty ? "<empty>" : incomingIdentifier)) | name: \(trimmedName ?? "<nil>") | resolved: \(resolvedMode.rawValue)")

                let finalIdentifier = resolvedMode.rawValue
                if finalIdentifier != self.currentFocusModeIdentifier {
                    self.currentFocusModeIdentifier = finalIdentifier
                }

                let finalName: String
                if let name = trimmedName, !name.isEmpty {
                    finalName = name
                } else if !resolvedMode.displayName.isEmpty {
                    finalName = resolvedMode.displayName
                } else if !incomingName.isEmpty {
                    finalName = incomingName
                } else {
                    finalName = "Focus"
                }

                if finalName != self.currentFocusModeName {
                    self.currentFocusModeName = finalName
                }

                guard self.isDoNotDisturbActive != isActive else { return }

                withAnimation(.smooth(duration: 0.25)) {
                    self.isDoNotDisturbActive = isActive
                }
            }
        }
    }

    private func extractMetadata(from notification: Notification) -> (name: String?, identifier: String?) {
        guard let userInfo = notification.userInfo else { return (nil, nil) }

        if !hasLoggedPayload {
            hasLoggedPayload = true
            debugPrint("[DoNotDisturbManager] focus notification payload: \(userInfo)")
        }

        let identifierKeys = [
            "FocusModeIdentifier",
            "focusModeIdentifier",
            "FocusModeUUID",
            "focusModeUUID",
            "UUID",
            "uuid",
            "identifier",
            "Identifier"
        ]

        let nameKeys = [
            "FocusModeName",
            "focusModeName",
            "FocusMode",
            "focusMode",
            "name",
            "Name"
        ]

        let identifier = identifierKeys
            .compactMap { userInfo[$0] as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        let name = nameKeys
            .compactMap { userInfo[$0] as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        return (name, identifier)
    }

}

private extension Notification.Name {
    static let focusModeEnabled = Notification.Name("_NSDoNotDisturbEnabledNotification")
    static let focusModeDisabled = Notification.Name("_NSDoNotDisturbDisabledNotification")
}

// MARK: - Focus Mode Types

enum FocusModeType: String, CaseIterable {
    case doNotDisturb = "com.apple.donotdisturb.mode"
    case work = "com.apple.focus.work"
    case personal = "com.apple.focus.personal"
    case sleep = "com.apple.focus.sleep"
    case driving = "com.apple.focus.driving"
    case fitness = "com.apple.focus.fitness"
    case gaming = "com.apple.focus.gaming"
    case mindfulness = "com.apple.focus.mindfulness"
    case reading = "com.apple.focus.reading"
    case custom = "com.apple.focus.custom"
    case unknown = ""
    
    var displayName: String {
        switch self {
        case .doNotDisturb: return "DnD"
        case .work: return "Work"
        case .personal: return "Personal"
        case .sleep: return "Sleep"
        case .driving: return "Driving"
        case .fitness: return "Fitness"
        case .gaming: return "Gaming"
        case .mindfulness: return "Mindfulness"
        case .reading: return "Reading"
        case .custom: return "Focus"
        case .unknown: return "Focus Mode"
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .doNotDisturb: return "moon.fill"
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .sleep: return "bed.double.fill"
        case .driving: return "car.fill"
        case .fitness: return "figure.run"
        case .gaming: return "gamecontroller.fill"
        case .mindfulness: return "brain.head.profile"
        case .reading: return "book.fill"
        case .custom: return "app.badge"
        case .unknown: return "moon.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .doNotDisturb:
            return Color(red: 0.370, green: 0.360, blue: 0.902)
        case .work:
            return Color(red: 0.133, green: 0.475, blue: 0.992)
        case .personal:
            return Color(red: 0.937, green: 0.282, blue: 0.624)
        case .sleep:
            return Color(red: 0.341, green: 0.384, blue: 0.980)
        case .driving:
            return Color(red: 0.988, green: 0.561, blue: 0.153)
        case .fitness:
            return Color(red: 0.176, green: 0.804, blue: 0.459)
        case .gaming:
            return Color(red: 0.639, green: 0.329, blue: 0.937)
        case .mindfulness:
            return Color(red: 0.239, green: 0.718, blue: 0.682)
        case .reading:
            return Color(red: 0.239, green: 0.596, blue: 0.965)
        case .custom:
            return Color(red: 0.513, green: 0.478, blue: 0.965)
        case .unknown:
            return Color(red: 0.370, green: 0.360, blue: 0.902)
        }
    }

    var inactiveSymbol: String {
        switch self {
        case .doNotDisturb:
            return "moon.circle.fill"
        default:
            return sfSymbol
        }
    }
}

extension FocusModeType {
    init(identifier: String) {
        let normalized = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLowercased = normalized.lowercased()

        guard !normalized.isEmpty else {
            self = .doNotDisturb
            return
        }

        if let direct = FocusModeType(rawValue: normalized) ?? FocusModeType(rawValue: normalizedLowercased) {
            self = direct
            return
        }

        if let resolved = FocusModeType.allCases.first(where: {
            guard !$0.rawValue.isEmpty else { return false }
            return normalized.hasPrefix($0.rawValue) || normalizedLowercased.hasPrefix($0.rawValue)
        }) {
            self = resolved
            return
        }

        if normalizedLowercased.hasPrefix("com.apple.focus.") {
            self = .custom
            return
        }

        self = .doNotDisturb
    }

    static func resolve(identifier: String?, name: String?) -> FocusModeType {
        let trimmedIdentifier = identifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedIdentifier.isEmpty {
            return FocusModeType(identifier: trimmedIdentifier)
        }

        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            if let match = FocusModeType.allCases.first(where: { !$0.displayName.isEmpty && $0.displayName.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                return match
            }
        }

        return .doNotDisturb
    }
}
