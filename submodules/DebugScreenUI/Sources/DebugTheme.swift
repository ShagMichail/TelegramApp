import UIKit
import Display
import TelegramPresentationData
import AccountContext

enum DebugTheme {
    static let background = UIColor(rgb: 0xF2F2F7)
    static let cellBackground = UIColor.white
    static let primaryText = UIColor.black
    static let secondaryText = UIColor(rgb: 0x8E8E93)
    static let accent = UIColor(rgb: 0xBF7A54)
    static let separator = UIColor(rgb: 0xC6C6C8)
    static let destructive = UIColor(rgb: 0xFF3B30)
    static let success = UIColor(rgb: 0x34C759)
    static let warning = UIColor(rgb: 0xFF9500)

    static func navTheme() -> NavigationBarTheme {
        return NavigationBarTheme(
            overallDarkAppearance: false,
            buttonColor: accent,
            disabledButtonColor: accent.withAlphaComponent(0.4),
            primaryTextColor: .black,
            backgroundColor: UIColor(rgb: 0xF8F8F8),
            opaqueBackgroundColor: UIColor(rgb: 0xF8F8F8),
            enableBackgroundBlur: false,
            separatorColor: separator,
            badgeBackgroundColor: .clear,
            badgeStrokeColor: .clear,
            badgeTextColor: .clear
        )
    }
}
