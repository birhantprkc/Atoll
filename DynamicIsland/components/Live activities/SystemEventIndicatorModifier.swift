    //
    //  SystemEventIndicatorModifier.swift
    //  DynamicIsland
    //
    //  Created by Richard Kunkli on 12/08/2024.
    //

import SwiftUI
import Defaults

struct SystemEventIndicatorModifier: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @Binding var eventType: SneakContentType
    @Binding var value: CGFloat {
        didSet {
            DispatchQueue.main.async {
                self.sendEventBack(value)
                self.vm.objectWillChange.send()
            }
        }
    }
    @Binding var icon: String
    let showSlider: Bool = false
    var sendEventBack: (CGFloat) -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            switch (eventType) {
                case .volume:
                    if icon.isEmpty {
                        Image(systemName: SpeakerSymbol(value))
                            .contentTransition(.interpolate)
                            .symbolVariant(value > 0 ? .none : .slash)
                            .frame(width: 20, height: 15, alignment: .leading)
                    } else {
                        Image(systemName: icon)
                            .contentTransition(.interpolate)
                            .opacity(value.isZero ? 0.6 : 1)
                            .scaleEffect(value.isZero ? 0.85 : 1)
                            .frame(width: 20, height: 15, alignment: .leading)
                    }
                case .brightness:
                    Image(systemName: "sun.max.fill")
                        .contentTransition(.symbolEffect)
                        .frame(width: 20, height: 15)
                        .foregroundStyle(.white)
                case .backlight:
                    Image(systemName: "keyboard")
                        .contentTransition(.symbolEffect)
                        .frame(width: 20, height: 15)
                        .foregroundStyle(.white)
                case .mic:
                    Image(systemName: "mic")
                        .symbolVariant(value > 0 ? .none : .slash)
                        .contentTransition(.interpolate)
                        .frame(width: 20, height: 15)
                        .foregroundStyle(.white)
                default:
                    EmptyView()
            }
            if (eventType != .mic) {
                DraggableProgressBar(value: $value)
            } else {
                Text("Mic \(value > 0 ? "unmuted" : "muted")")
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .allowsTightening(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .symbolVariant(.fill)
        .imageScale(.large)
    }
    
    func SpeakerSymbol(_ value: CGFloat) -> String {
        switch(value) {
            case 0:
                return "speaker.slash"
            case 0...0.3:
                return "speaker.wave.1"
            case 0.3...0.8:
                return "speaker.wave.2"
            case 0.8...1:
                return "speaker.wave.3"
            default:
                return "speaker.wave.2"
        }
    }
}

struct DraggableProgressBar: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @Binding var value: CGFloat
    
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack {
            GeometryReader { geo in
                Group {
                    if Defaults[.progressBarStyle] == .segmented {
                        // Segmented progress bar - completely different layout
                        SegmentedProgressContent(value: value, geometry: geo)
                    } else {
                        // Traditional capsule-based progress bar
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.tertiary)
                            Group {
                                switch Defaults[.progressBarStyle] {
                                case .gradient:
                                    Capsule()
                                        .fill(LinearGradient(colors: Defaults[.systemEventIndicatorUseAccent] ? [Defaults[.accentColor], Defaults[.accentColor].ensureMinimumBrightness(factor: 0.2)] : [.white, .white.opacity(0.2)], startPoint: .trailing, endPoint: .leading))
                                        .frame(width: max(0, min(geo.size.width * value, geo.size.width)))
                                        .shadow(color: Defaults[.systemEventIndicatorShadow] ? Defaults[.systemEventIndicatorUseAccent] ? Defaults[.accentColor].ensureMinimumBrightness(factor: 0.7) : .white : .clear, radius: 8, x: 3)
                                case .hierarchical:
                                    Capsule()
                                        .fill(Defaults[.systemEventIndicatorUseAccent] ? Defaults[.accentColor] : .white)
                                        .frame(width: max(0, min(geo.size.width * value, geo.size.width)))
                                        .shadow(color: Defaults[.systemEventIndicatorShadow] ? Defaults[.systemEventIndicatorUseAccent] ? Defaults[.accentColor].ensureMinimumBrightness(factor: 0.7) : .white : .clear, radius: 8, x: 3)
                                case .segmented:
                                    EmptyView() // This case won't be reached due to the outer if condition
                                }
                            }
                            .opacity(value.isZero ? 0 : 1)
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            withAnimation(.smooth(duration: 0.3)) {
                                isDragging = true
                                updateValue(gesture: gesture, in: geo)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.smooth(duration: 0.3)) {
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: Defaults[.inlineHUD] ? isDragging ? 8 : 5 : isDragging ? 9 : 6)
        }
    }
    
    private func updateValue(gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let dragPosition = gesture.location.x
        let newValue = dragPosition / geometry.size.width
        
        value = max(0, min(newValue, 1))
    }
}

struct SegmentedProgressContent: View {
    let value: CGFloat
    let geometry: GeometryProxy
    
    private let segmentCount = 16
    @State private var glowIndex: Int? = nil
    @State private var lastValue: CGFloat = 0
    
    var body: some View {
        let spacing: CGFloat = 1.5
        let computed = (geometry.size.width - CGFloat(segmentCount - 1) * spacing) / CGFloat(segmentCount)
        let barWidth = max(3.0, min(6.0, computed))
        let activeCount = Int(round(value * CGFloat(segmentCount)))
        
        HStack(spacing: spacing) {
            ForEach(0..<segmentCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(segmentColor(isActive: index < activeCount))
                    .shadow(
                        color: Defaults[.systemEventIndicatorShadow]
                            ? glowShadowColor(for: index < activeCount, index: index)
                            : .clear,
                        radius: Defaults[.systemEventIndicatorShadow]
                            ? (glowIndex == index ? 12 : (index < activeCount ? 4 : 0))
                            : 0,
                        x: 0, y: 0
                    )
                    .frame(width: barWidth)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeCount)
                    .scaleEffect(glowIndex == index ? 1.15 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: glowIndex == index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .opacity(value.isZero ? 0 : 1)
        .onChange(of: value) { old, newVal in
            handleGlow(oldValue: old, newValue: newVal)
        }
    }
    
    private func segmentColor(isActive: Bool) -> Color {
        if isActive {
            if Defaults[.systemEventIndicatorUseAccent] {
                return Defaults[.accentColor]
            }
            return .white
        } else {
            return .white.opacity(0.15)
        }
    }
    
    private func glowShadowColor(for isActive: Bool, index: Int) -> Color {
        if isActive {
            if let glowIndex = glowIndex, index == glowIndex {
                return Defaults[.systemEventIndicatorUseAccent]
                    ? Defaults[.accentColor].ensureMinimumBrightness(factor: 0.8)
                    : .white
            } else {
                return Defaults[.systemEventIndicatorUseAccent]
                    ? Defaults[.accentColor].ensureMinimumBrightness(factor: 0.7)
                    : .white
            }
        }
        return .clear
    }
    
    private func handleGlow(oldValue: CGFloat, newValue: CGFloat) {
        defer { lastValue = newValue }
        let oldIndex = Int(round(oldValue * CGFloat(segmentCount)))
        let newIndex = Int(round(newValue * CGFloat(segmentCount)))
        guard oldIndex != newIndex else { return }

        if newIndex > oldIndex {
            animateWave(from: oldIndex, to: newIndex, step: 1)
        } else {
            animateWave(from: oldIndex - 1, to: newIndex - 1, step: -1)
        }
    }
    
    private func animateWave(from start: Int, to end: Int, step: Int) {
        let clampedStart = max(0, min(segmentCount - 1, start))
        let clampedEnd = max(-1, min(segmentCount - 1, end))
        let range = stride(from: clampedStart, through: clampedEnd, by: step)
        var delay: Double = 0
        for i in range {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    glowIndex = i
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.2) {
                if glowIndex == i {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        glowIndex = nil
                    }
                }
            }
            delay += 0.015
        }
    }
}
