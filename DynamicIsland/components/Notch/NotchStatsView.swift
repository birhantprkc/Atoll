//
//  NotchStatsView.swift
//  DynamicIsland
//
//  Adapted from boring.notch StatsView 
//  Stats tab view for system performance monitoring with clickable process popovers

import SwiftUI
import Defaults

// Graph data protocol for unified interface
protocol GraphData {
    var title: String { get }
    var color: Color { get }
    var icon: String { get }
    var type: GraphType { get }
}

enum GraphType {
    case single
    case dual
}

// Single value graph data
struct SingleGraphData: GraphData {
    let title: String
    let value: String
    let data: [Double]
    let color: Color
    let icon: String
    let type: GraphType = .single
}

struct NotchStatsView: View {
    @ObservedObject var statsManager = StatsManager.shared
    @Default(.enableStatsFeature) var enableStatsFeature
    @State private var showingCPUPopover = false
    @State private var showingMemoryPopover = false
    @State private var showingGPUPopover = false
    @State private var isHoveringCPUPopover = false
    @State private var isHoveringMemoryPopover = false
    @State private var isHoveringGPUPopover = false
    @EnvironmentObject var vm: DynamicIslandViewModel
    
    var availableGraphs: [GraphData] {
        var graphs: [GraphData] = []
        
        // Only CPU, Memory, and GPU as in boring.notch - no network/disk
        graphs.append(SingleGraphData(
            title: "CPU",
            value: statsManager.cpuUsageString,
            data: statsManager.cpuHistory,
            color: .blue,
            icon: "cpu"
        ))
        
        graphs.append(SingleGraphData(
            title: "Memory",
            value: statsManager.memoryUsageString,
            data: statsManager.memoryHistory,
            color: .green,
            icon: "memorychip"
        ))
        
        graphs.append(SingleGraphData(
            title: "GPU",
            value: statsManager.gpuUsageString,
            data: statsManager.gpuHistory,
            color: .purple,
            icon: "display"
        ))
        
        return graphs
    }
    
    // Restored original 3-graph layout from boring.notch
    @ViewBuilder
    var statsGridLayout: some View {
        // 3 graphs: Single row with proper spacing - matches boring.notch exactly
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(0..<availableGraphs.count, id: \.self) { index in
                let graphData = availableGraphs[index]
                
                Button(action: {
                    handleGraphClick(for: graphData)
                }) {
                    UnifiedStatsCard(graphData: graphData)
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: bindingForGraph(graphData)) {
                    RankedProcessPopover(
                        rankingType: rankingTypeForGraph(graphData),
                        onHoverChange: { hovering in
                            switch graphData.title {
                            case "CPU":
                                isHoveringCPUPopover = hovering
                            case "Memory":
                                isHoveringMemoryPopover = hovering
                            case "GPU":
                                isHoveringGPUPopover = hovering
                            default:
                                break
                            }
                        }
                    )
                    .onDisappear {
                        // Reset hover states when popover disappears
                        switch graphData.title {
                        case "CPU":
                            isHoveringCPUPopover = false
                        case "Memory":
                            isHoveringMemoryPopover = false
                        case "GPU":
                            isHoveringGPUPopover = false
                        default:
                            break
                        }
                        // Ensure popover state is updated when popover disappears
                        DispatchQueue.main.async {
                            updateStatsPopoverState()
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4)),
                    removal: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4))
                ))
            }
        }
    }
    
    private func handleGraphClick(for graphData: GraphData) {
        switch graphData.title {
        case "CPU":
            showingCPUPopover = true
        case "Memory":
            showingMemoryPopover = true
        case "GPU":
            showingGPUPopover = true
        default:
            break
        }
    }
    
    private func bindingForGraph(_ graphData: GraphData) -> Binding<Bool> {
        switch graphData.title {
        case "CPU":
            return $showingCPUPopover
        case "Memory":
            return $showingMemoryPopover
        case "GPU":
            return $showingGPUPopover
        default:
            return .constant(false)
        }
    }
    
    private func rankingTypeForGraph(_ graphData: GraphData) -> ProcessRankingType {
        switch graphData.title {
        case "CPU":
            return .cpu
        case "Memory":
            return .memory
        case "GPU":
            return .gpu
        default:
            return .cpu
        }
    }
    
    // Helper function to create graph views using unified component
    @ViewBuilder
    func graphView(for graphData: GraphData) -> some View {
        UnifiedStatsCard(graphData: graphData)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !enableStatsFeature {
                // Disabled state
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("Stats Disabled")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Enable stats monitoring in Settings to view system performance data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Stats content - restored to original boring.notch 3-graph layout
                VStack(spacing: 8) {
                    statsGridLayout
                }
                .padding(12)
                .animation(.easeInOut(duration: 0.4), value: availableGraphs.count)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4)),
                    removal: .scale.combined(with: .opacity).animation(.easeInOut(duration: 0.4))
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if enableStatsFeature && Defaults[.autoStartStatsMonitoring] && !statsManager.isMonitoring {
                statsManager.startMonitoring()
            }
        }
        .onDisappear {
            // Keep monitoring running when tab is not visible
        }
        .animation(.easeInOut(duration: 0.4), value: enableStatsFeature)
        .animation(.easeInOut(duration: 0.4), value: availableGraphs.count)
        .onChange(of: showingCPUPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: showingMemoryPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: showingGPUPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: isHoveringCPUPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: isHoveringMemoryPopover) { _, _ in
            updateStatsPopoverState()
        }
        .onChange(of: isHoveringGPUPopover) { _, _ in
            updateStatsPopoverState()
        }
    }
    
    private func updateStatsPopoverState() {
        // Use the same logic as battery popover: active only when shown AND hovered
        let newState = (showingCPUPopover && isHoveringCPUPopover) || 
                       (showingMemoryPopover && isHoveringMemoryPopover) || 
                       (showingGPUPopover && isHoveringGPUPopover)
        if vm.isStatsPopoverActive != newState {
            vm.isStatsPopoverActive = newState
            #if DEBUG
            print("📊 Stats popover state updated: \(newState)")
            print("   CPU: shown=\(showingCPUPopover), hovering=\(isHoveringCPUPopover)")
            print("   Memory: shown=\(showingMemoryPopover), hovering=\(isHoveringMemoryPopover)")
            print("   GPU: shown=\(showingGPUPopover), hovering=\(isHoveringGPUPopover)")
            #endif
        }
    }
}

// Unified Stats Card Component - now clickable for popovers, matches boring.notch sizing
struct UnifiedStatsCard: View {
    let graphData: GraphData
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 3) {
            // Header with title on left and percentage on right - matches boring.notch layout
            HStack(spacing: 4) {
                // Title and icon on left
                HStack(spacing: 3) {
                    Image(systemName: graphData.icon)
                        .foregroundColor(graphData.color)
                        .font(.caption)
                    
                    Text(graphData.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Percentage value on right
                if let singleData = graphData as? SingleGraphData {
                    Text(singleData.value)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            
            // Graph section - full height since no separate value section, matches boring.notch
            Group {
                if let singleData = graphData as? SingleGraphData {
                    MiniGraph(data: singleData.data, color: singleData.color)
                }
            }
            .frame(height: 36) // Matches boring.notch exactly - reduced from 50px
            
            // Click hint
            Text("Click for details")
                .font(.caption2)
                .foregroundColor(.secondary)
                .opacity(isHovered ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .padding(8) // Reduced padding to match boring.notch
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(graphData.color.opacity(isHovered ? 0.5 : 0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct MiniGraph: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.max() ?? 1.0
            let normalizedData = maxValue > 0 ? data.map { $0 / maxValue } : data
            
            Path { path in
                guard !normalizedData.isEmpty else { return }
                
                let stepX = geometry.size.width / CGFloat(normalizedData.count - 1)
                
                for (index, value) in normalizedData.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height * (1 - CGFloat(value))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 2)
            
            // Gradient fill
            Path { path in
                guard !normalizedData.isEmpty else { return }
                
                let stepX = geometry.size.width / CGFloat(normalizedData.count - 1)
                
                path.move(to: CGPoint(x: 0, y: geometry.size.height))
                
                for (index, value) in normalizedData.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height * (1 - CGFloat(value))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}



#Preview {
    NotchStatsView()
        .frame(width: 400, height: 300)
        .background(Color.black)
}
