//
//  FocusIndicator.swift
//  DynamicIsland
//
//  Small purple moon badge shown while Focus mode is active.
//

import SwiftUI

struct FocusIndicator: View {
    @ObservedObject var manager = DoNotDisturbManager.shared

    var body: some View {
        Capsule()
            .fill(Color.black)
            .overlay {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 20, height: 20)

                    Image(systemName: focusSymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
    }

    private var focusMode: FocusModeType {
        FocusModeType(rawValue: manager.currentFocusModeIdentifier) ?? .doNotDisturb
    }

    private var focusSymbol: String {
        focusMode.sfSymbol
    }

    private var accentColor: Color {
        focusMode.accentColor
    }

    private var accessibilityLabel: String {
        let name = manager.currentFocusModeName.isEmpty ? focusMode.displayName : manager.currentFocusModeName
        return "Focus active: \(name)"
    }
}

#Preview {
    FocusIndicator()
        .frame(width: 30, height: 30)
        .background(Color.gray.opacity(0.2))
}
