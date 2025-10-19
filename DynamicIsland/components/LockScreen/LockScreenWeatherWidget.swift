import SwiftUI

struct LockScreenWeatherWidget: View {
    let snapshot: LockScreenWeatherSnapshot

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: snapshot.symbolName)
                .font(.system(size: 26, weight: .medium))
                .symbolRenderingMode(.hierarchical)
            Text(snapshot.temperatureText)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .kerning(-0.4)
        }
        .foregroundStyle(Color.white.opacity(0.65))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.clear)
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weather: \(snapshot.description) \(snapshot.temperatureText)")
    }
}
