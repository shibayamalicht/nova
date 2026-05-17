import SwiftUI

enum Theme {
    static let cyan = Color(red: 0/255, green: 229/255, blue: 255/255)
    static let purple = Color(red: 168/255, green: 85/255, blue: 247/255)
    static let pink = Color(red: 236/255, green: 72/255, blue: 153/255)

    static let accent = LinearGradient(
        colors: [cyan, purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentHorizontal = LinearGradient(
        colors: [cyan, purple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let accentBright = LinearGradient(
        colors: [cyan, purple, pink],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let glassStroke = LinearGradient(
        colors: [.white.opacity(0.25), .white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
