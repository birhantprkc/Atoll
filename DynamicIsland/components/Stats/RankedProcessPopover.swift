//
//  RankedProcessPopover.swift
//  DynamicIsland
//
//  Popover component for displaying ranked processes by different metrics
//  Adapted from boring.notch implementation

import SwiftUI

struct RankedProcessPopover: View {
    let rankingType: ProcessRankingType
    @Environment(\.dismiss) private var dismiss
    
    // Callback to notify parent about hover state
    var onHoverChange: ((Bool) -> Void)?
    
    private var configuration: (width: CGFloat, minHeight: CGFloat, padding: CGFloat) {
        switch rankingType {
        case .cpu:
            return (420, 420, 0)
        case .memory:
            return (400, 380, 0)
        case .gpu:
            return (380, 360, 0)
        case .network, .disk:
            return (360, 320, 0)
        }
    }
    
    var body: some View {
        popoverContent
            .padding(configuration.padding)
            .frame(width: configuration.width)
            .frame(minHeight: configuration.minHeight)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 8)
            .overlay(alignment: .topTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onHover { hovering in
                onHoverChange?(hovering)
            }
    }
    
    @ViewBuilder
    private var popoverContent: some View {
        switch rankingType {
        case .cpu:
            CPUStatsDetailView()
        case .memory:
            MemoryStatsDetailView()
        case .gpu:
            GPUStatsDetailView()
        case .network:
            NetworkStatsDetailView()
        case .disk:
            DiskStatsDetailView()
        }
    }
}