//
//  StatsFormatting.swift
//  DynamicIsland
//
//  Lightweight formatters shared across stats detail popovers.
//
//  Created by GitHub Copilot on 19/10/2025.
//

import Foundation

enum StatsFormatting {
    static func bytes(_ value: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(value))
    }
    
    static func mbPerSecond(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 10 ? 1 : 2
        let number = NSNumber(value: value)
        let formatted = formatter.string(from: number) ?? String(format: "%.2f", value)
        return "\(formatted) MB/s"
    }
    
    static func percentage(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
    
    static func gigabytes(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 10 ? 1 : 2
        return (formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)) + " GB"
    }

    static func abbreviatedDuration(_ value: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: value) ?? "—"
    }
}
