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
                            SegmentedProgressContent(value: value, geometry: geo)
                        }
                    }
                    .opacity(value.isZero ? 0 : 1)
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
    
    private let segmentCount = 20
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<segmentCount, id: \.self) { index in
                let segmentValue = CGFloat(index + 1) / CGFloat(segmentCount)
                let isActive = value >= segmentValue
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(isActive ? 
                          (Defaults[.systemEventIndicatorUseAccent] ? Defaults[.accentColor] : .white) : 
                          .clear)
                    .frame(width: max(1, (geometry.size.width - CGFloat(segmentCount - 1) * 1) / CGFloat(segmentCount)))
                    .shadow(color: isActive && Defaults[.systemEventIndicatorShadow] ? 
                           (Defaults[.systemEventIndicatorUseAccent] ? Defaults[.accentColor].ensureMinimumBrightness(factor: 0.7) : .white) : 
                           .clear, radius: 4, x: 1)
                    .opacity(value.isZero ? 0 : (isActive ? 1 : 0.3))
            }
        }
        .frame(width: geometry.size.width)
    }
}
