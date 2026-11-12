import Foundation
import Ignite
import Testing
@testable import SponsoredByIndiesWebsite

struct DesignTokensTests {
    @Test @MainActor func paletteChangeReachesThemeStylesheetAndArtwork() throws {
        var palette = BrandPalette()
        palette.blue = "#123456"
        let theme = IndiesTheme(palette: palette)
        #expect(theme.accent == Color(hex: "#123456"))
        #expect(theme.link == theme.accent)
        #expect(DesignTokens.stylesheet(palette: palette).contains("--blue: #123456;"))

        let svg = #"<svg><path fill="var(--blue, #245BC7)" d="M1 2L3 4"/><circle fill="var(--accent, #B9470D)" r="5"/></svg>"#
        let result = try DesignTokens.renderSVG(svg, palette: palette)
        #expect(result.contains("fill=\"#123456\""))
        #expect(result.contains("fill=\"\(palette.accent)\""))
        #expect(result.contains(#"d="M1 2L3 4""#))
        #expect(result.contains(#"r="5""#))
        #expect(!result.contains("var(--"))
    }

    @Test(arguments: ["var(--missing, #ffffff)", "var(--blue)"])
    func invalidArtworkBindingFailsBeforeInstallation(binding: String) {
        #expect(throws: DesignTokens.TokenError.self) {
            try DesignTokens.renderSVG("<svg fill=\"\(binding)\"/>")
        }
    }
}
