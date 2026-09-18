import SwiftUI
import UIKit

// Adaptive colors keep the same palette for Dark and dark System appearance.
enum GarageTheme {
    static let background = adaptive(0x313338, light: .systemGroupedBackground)
    static let surface = adaptive(0x383A40, light: .secondarySystemGroupedBackground)
    static let chrome = adaptive(0x2B2D31, light: .systemBackground)
    static let border = adaptive(0x626773, light: .separator)
    static let userBubble = adaptive(0x41476B, light: .secondarySystemGroupedBackground)
    static let accent = adaptive(0xA5ACFF, light: .systemBlue)

    private static func adaptive(_ hex: Int, light: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            guard traits.userInterfaceStyle == .dark else { return light }
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}
