//
//  LockScreenLiveActivity.swift
//  DynamicIsland
//
//  Created for lock screen live activity
//

import SwiftUI
import Defaults

struct LockScreenLiveActivity: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject private var lockScreenManager = LockScreenManager.shared
    @State private var isHovering: Bool = false
    @State private var gestureProgress: CGFloat = 0
    @State private var isExpanded: Bool = false
    @Namespace private var lockIconSpace

    private var iconName: String {
        lockScreenManager.isLocked ? "lock.fill" : "lock.open.fill"
    }

    private var iconColor: Color {
        lockScreenManager.isLocked ? .blue : .green
    }

    private var glowColor: Color {
        lockScreenManager.isLocked ? Color.blue.opacity(0.15) : Color.green.opacity(0.2)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left - Lock icon with subtle glow
            Color.clear
                .background {
                    if isExpanded {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(glowColor)
                                
                                Image(systemName: iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(iconColor)
                                    .modifier(LockPulsingModifier(isUnlocking: !lockScreenManager.isLocked))
                                    .matchedGeometryEffect(id: "lock-icon", in: lockIconSpace)
                            }
                            .frame(width: vm.effectiveClosedNotchHeight - 12, height: vm.effectiveClosedNotchHeight - 12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                }
                .frame(width: isExpanded ? max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2) : 0, height: vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
            
            // Center - Black fill
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + (isHovering ? 8 : 0))
            
            // Right - Empty for symmetry with animation
            Color.clear
                .frame(width: isExpanded ? max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12) + gestureProgress / 2) : 0, height: vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
        }
        .frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0))
        .onAppear {
            // Expand immediately without animation to avoid conflicts
            withAnimation(.smooth(duration: 0.4)) {
                isExpanded = true
            }
        }
        .onDisappear {
            // Collapse immediately when removed from hierarchy
            isExpanded = false
        }
        .onChange(of: lockScreenManager.isLockIdle) { _, newValue in
            if newValue {
                withAnimation(.smooth(duration: 0.4)) {
                    isExpanded = false
                }
            } else {
                withAnimation(.smooth(duration: 0.4)) {
                    isExpanded = true
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: lockScreenManager.isLocked)
        .animation(.easeOut(duration: 0.25), value: isExpanded)
    }
}

// Pulsing animation modifier for lock indicator
struct LockPulsingModifier: ViewModifier {
    var isUnlocking: Bool
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.1 : 1.0)
            .opacity(isPulsing ? (isUnlocking ? 1.0 : 0.8) : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onDisappear {
                isPulsing = false
            }
    }
}
