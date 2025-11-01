//
//  TimerLiveActivity.swift
//  DynamicIsland
//
//  Created by Ebullioscopic on 2025-01-13.
//

import SwiftUI
import Defaults

#if canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
#elseif canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
#endif

struct TimerLiveActivity: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject var timerManager = TimerManager.shared
    @State private var isHovering: Bool = false
    @Default(.timerShowsCountdown) private var showsCountdown
    @Default(.timerShowsProgress) private var showsProgress
    @Default(.timerShowsLabel) private var showsLabel
    @Default(.timerProgressStyle) private var progressStyle
    @Default(.timerIconColorMode) private var colorMode
    @Default(.timerSolidColor) private var solidColor
    @Default(.timerPresets) private var timerPresets
    
    private var notchContentHeight: CGFloat {
        max(0, vm.effectiveClosedNotchHeight - (isHovering ? 0 : 12))
    }

    private var wingPadding: CGFloat { 18 }

    private var ringWrapsIcon: Bool {
        showsRingProgress && showsCountdown
    }

    private var ringOnRight: Bool {
        showsRingProgress && !ringWrapsIcon
    }

    private var iconWidth: CGFloat {
        ringWrapsIcon ? max(notchContentHeight, 32) : max(0, notchContentHeight)
    }

    private var infoContentWidth: CGFloat {
        guard showsInfoSection else { return 0 }
        let textWidth = min(max(titleTextWidth, 44), 220)
        if showsLabel {
            return textWidth
        } else {
            return min(max(notchContentHeight * 1.4, 64), 220)
        }
    }

    private var infoWidth: CGFloat {
        guard showsInfoSection else { return 0 }
        return infoContentWidth + 18
    }

    private var leftWingWidth: CGFloat {
        var width = iconWidth + wingPadding
        if showsInfoSection {
            width += 8 + infoWidth
        }
        return width
    }

    private var ringWidth: CGFloat {
        ringOnRight ? 32 : 0
    }

    private var rightWingWidth: CGFloat {
        var width = wingPadding
        if ringOnRight {
            width += ringWidth
        }
        if ringOnRight && showsCountdown {
            width += 8
        }
        if showsCountdown {
            width += countdownWidth
        }
        return width
    }

    private var titleTextWidth: CGFloat {
        measureTextWidth(timerManager.timerName, font: systemFont(size: 12, weight: .medium))
    }

    private var countdownTextWidth: CGFloat {
        measureTextWidth(timerManager.formattedRemainingTime(), font: monospacedDigitFont(size: 13, weight: .semibold))
    }

    private var countdownWidth: CGFloat {
        guard showsCountdown else { return 0 }
        return max(countdownTextWidth + 20, 80)
    }

    private var clampedProgress: Double {
        min(max(timerManager.progress, 0), 1)
    }

    private var glyphColor: Color {
        switch colorMode {
        case .adaptive:
            return activePresetColor ?? timerManager.timerColor
        case .solid:
            return solidColor
        }
    }

    private var showsRingProgress: Bool {
        showsProgress && progressStyle == .ring
    }

    private var showsBarProgress: Bool {
        showsProgress && progressStyle == .bar
    }

    private var showsInfoSection: Bool {
        showsLabel || (showsBarProgress && !showsCountdown)
    }

    private var activePresetColor: Color? {
        guard let presetId = timerManager.activePresetId else { return nil }
        return timerPresets.first { $0.id == presetId }?.color
    }
    
    private func measureTextWidth(_ text: String, font: PlatformFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let width = NSAttributedString(string: text, attributes: attributes).size().width
        return CGFloat(ceil(width))
    }

    private func systemFont(size: CGFloat, weight: PlatformFont.Weight) -> PlatformFont {
        #if canImport(AppKit)
        return NSFont.systemFont(ofSize: size, weight: weight)
        #else
        return UIFont.systemFont(ofSize: size, weight: weight)
        #endif
    }

    private func monospacedDigitFont(size: CGFloat, weight: PlatformFont.Weight) -> PlatformFont {
        #if canImport(AppKit)
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        #else
        return UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        #endif
    }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: leftWingWidth, height: notchContentHeight)
                .background(alignment: .leading) {
                    HStack(spacing: showsInfoSection ? 8 : 0) {
                        iconSection
                        if showsInfoSection {
                            infoSection
                        }
                    }
                    .padding(.leading, wingPadding / 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + (isHovering ? 8 : 0), height: notchContentHeight)

            Color.clear
                .frame(width: rightWingWidth, height: notchContentHeight)
                .background(alignment: .trailing) {
                    HStack(spacing: ringOnRight && showsCountdown ? 8 : 0) {
                        if ringOnRight {
                            ringSection
                        }
                        if showsCountdown {
                            countdownSection
                        }
                    }
                    .padding(.trailing, wingPadding / 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
        }
        .frame(height: vm.effectiveClosedNotchHeight + (isHovering ? 8 : 0), alignment: .center)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.18)) {
                isHovering = hovering
            }
        }
    }
    
    private var iconSection: some View {
        let ringDiameter = ringWrapsIcon ? max(iconWidth, 32) : iconWidth
        let iconSize = ringWrapsIcon ? max(ringDiameter - 10, 18) : max(20, iconWidth - 4)

        return ZStack {
            if ringWrapsIcon {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: ringDiameter, height: ringDiameter)

                Circle()
                    .trim(from: 0, to: clampedProgress)
                    .stroke(glyphColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.25), value: clampedProgress)
                    .frame(width: ringDiameter, height: ringDiameter)
            }

            Image(systemName: "timer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(glyphColor)
                .frame(width: iconSize, height: iconSize)
        }
        .frame(width: ringWrapsIcon ? ringDiameter : iconWidth,
               height: notchContentHeight,
               alignment: .center)
    }
    
    private var infoSection: some View {
        let availableWidth = max(0, infoWidth - 18)
        let resolvedTextWidth = min(max(titleTextWidth, 44), availableWidth)
        let shouldMarquee = showsLabel && (timerManager.isFinished || timerManager.isOvertime || titleTextWidth > availableWidth)
        let showsBarHere = showsBarProgress && !showsCountdown
        let barWidth = showsLabel ? resolvedTextWidth : availableWidth

        return Rectangle()
            .fill(.black)
            .frame(width: infoWidth, height: notchContentHeight)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: showsBarHere ? 4 : 0) {
                    if showsLabel {
                        if shouldMarquee {
                            MarqueeText(
                                .constant(timerManager.timerName),
                                font: .system(size: 12, weight: .medium),
                                nsFont: .callout,
                                textColor: .white,
                                minDuration: 0.25,
                                frameWidth: resolvedTextWidth
                            )
                        } else {
                            Text(timerManager.timerName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .foregroundStyle(.white)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .frame(width: resolvedTextWidth, alignment: .leading)
                        }
                    }

                    if showsBarHere {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: barWidth, height: 3)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(glyphColor)
                                    .frame(width: barWidth * max(0, CGFloat(clampedProgress)))
                                    .animation(.smooth(duration: 0.25), value: clampedProgress)
                            }
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 6)
            }
            .animation(.smooth, value: timerManager.isFinished)
    }
    
    private var ringSection: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(glyphColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.25), value: clampedProgress)
        }
        .frame(width: 26, height: 26)
        .frame(width: ringWidth, height: notchContentHeight, alignment: .center)
    }
    
    private var countdownSection: some View {
        let barWidth = max(countdownTextWidth, 1)
        return VStack(spacing: 4) {
            Text(timerManager.formattedRemainingTime())
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(timerManager.isOvertime ? .red : .white)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: timerManager.remainingTime)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            if showsBarProgress {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: barWidth, height: 3)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(glyphColor)
                            .frame(width: barWidth * max(0, CGFloat(clampedProgress)))
                            .animation(.smooth(duration: 0.25), value: clampedProgress)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.trailing, 8)
     .frame(width: countdownWidth,
         height: notchContentHeight, alignment: .center)
    }
}

#Preview {
    TimerLiveActivity()
        .environmentObject(DynamicIslandViewModel())
        .frame(width: 300, height: 32)
        .background(.black)
        .onAppear {
            TimerManager.shared.startDemoTimer(duration: 300)
        }
}
