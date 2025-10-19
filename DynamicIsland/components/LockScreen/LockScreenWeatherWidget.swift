import SwiftUI

struct LockScreenWeatherWidget: View {
    let snapshot: LockScreenWeatherSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: snapshot.symbolName)
                .font(.system(size: 26, weight: .medium))
                .symbolRenderingMode(.hierarchical)
            Text(snapshot.temperatureText)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .kerning(-0.4)
            if let locationName = snapshot.locationName, !locationName.isEmpty {
                Text("•")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(locationName)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
        }
        .foregroundStyle(Color.white.opacity(0.65))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.clear)
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let locationName = snapshot.locationName, !locationName.isEmpty {
            return String(
                format: NSLocalizedString("Weather: %@ %@ in %@", comment: "Weather description, temperature, and location"),
                snapshot.description,
                snapshot.temperatureText,
                locationName
            )
        }

        return String(
            format: NSLocalizedString("Weather: %@ %@", comment: "Weather description and temperature"),
            snapshot.description,
            snapshot.temperatureText
        )
    }
}
