import Ignite

struct IndiesTheme: Theme {
    var palette = DesignTokens.palette
    var colorScheme: ColorScheme = .light
    var accent: Color { Color(hex: palette.blue) }
    var primary: Color { Color(hex: palette.accent) }
    var secondary: Color { Color(hex: palette.muted) }
    var secondaryAccent: Color { Color(hex: palette.muted) }
    var danger: Color { Color(hex: palette.accent) }
    var background: Color { Color(hex: palette.paper) }
    var secondaryBackground: Color { Color(hex: palette.tint) }
    var link: Color { Color(hex: palette.blue) }
    var hoveredLink: Color { Color(hex: palette.accent) }
    var border: Color { Color(hex: palette.line) }
}
