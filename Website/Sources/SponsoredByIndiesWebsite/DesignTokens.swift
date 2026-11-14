import CryptoKit
import Foundation

/// The editable palette. Both Ignite and generated browser assets consume it.
struct BrandPalette: Sendable {
    var blue = "#245bc7"
    var ink = "#142a50"
    var paper = "#f7f9fd"
    var muted = "#526078"
    var accent = "#b9470d"
    var accentSoft = "#ffad6b"
    var accentHover = "#96380a"
    var surface = "#ffffff"
    var tint = "#edf3ff"
    var line = "#d4dced"
    var rule = "#7e8ca4"
    var white = "#ffffff"

    var properties: [(String, String)] {
        [("blue", blue), ("ink", ink), ("paper", paper), ("muted", muted),
         ("accent", accent), ("accent-soft", accentSoft), ("accent-hover", accentHover),
         ("surface", surface), ("tint", tint), ("line", line), ("rule", rule), ("white", white)]
    }
}

enum DesignTokens {
    static let palette = BrandPalette()
    static let productIconSize = 64
    static let productIconRadius = 14
    static let brandAssetNames = ["logo.svg", "logo-inverse.svg", "favicon.svg", "favicon-shared-imprint-01.svg"]
    static let brandMarkSize = 76.0
    static let brandLabelSize = 20.0
    static let brandNameSize = 42.4
    static let brandGap = 12.0
    static let brandLineGap = 2.0

    // Base scale, then semantic roles. Keep page composition free of repeated values.
    static let spacing = """
      --space-1: .25rem;
      --space-2: .5rem;
      --space-3: .75rem;
      --space-4: 1rem;
      --space-5: 1.25rem;
      --space-6: 1.5rem;
      --space-8: 2rem;
      --space-10: 2.5rem;
      --space-12: 3rem;
      --space-16: 4rem;
      --section-space: clamp(var(--space-8), calc(var(--space-6) + 2vw), var(--space-12));
      --page-gutter: var(--space-6);
      --page-navigation-inset: var(--space-6);
      --hero-inset: clamp(var(--space-10), calc(var(--space-8) + 2vw), var(--space-16));
      --card-inset: min(var(--space-10), 5vw);
      --conference-inset: var(--space-10);
      --conference-inset-small: var(--space-6);
      --community-inset: calc(var(--section-space) * 1.5);
      --heading-gap: 1.8rem;
      --action-gap: 1.7rem;
      --action-row-gap: .6rem;
      --eyebrow-gap: 1.4rem;
      --brand-base-size: min(1rem, 4vw);
      --brand-gap: \(brandGap / 16)em;
      --brand-mark-size: \(brandMarkSize / 16)em;
      --brand-label-size: \(brandLabelSize / 16)em;
      --brand-name-size: \(brandNameSize / 16)em;
      --brand-line-gap: \(brandLineGap / 16)em;
      --brand-line-height: 1.05;
      --brand-signature-gap: .3em;
      --button-inset-block: .8rem;
      --button-inset-inline: var(--space-5);
      --control-inset-block: .65rem;
      --control-inset-inline: .8rem;
      --step-inset: .4rem;
      --breadcrumb-gap: .8rem;
      --separator-inset-start: .2rem;
      --separator-inset-end: .9rem;
      --edition-link-inset-block: .3rem;
      --edition-link-inset-inline: .8rem;
      --radius-small: .3rem;
      --radius-card: .5rem;
      --target-size: 44px;
      --link-underline-offset: .23em;
      --border-width: 1px;
      --control-border-width: 2px;
      --focus-width: 3px;
      --focus-offset: var(--focus-width);
      --focus-halo: 6px;
      --focus-radius: 2px;
      --reading-width: 52rem;
      --offer-heading-size: 1.125rem;
    """

    static func stylesheet(palette: BrandPalette = DesignTokens.palette) -> String {
        let colors = palette.properties.map { "  --\($0.0): \($0.1);" }.joined(separator: "\n")
        return """
        /* Generated from DesignTokens.swift. Edit the source, then rebuild. */
        :root {
        \(colors)
        \(spacing)
        }
        /* Retain Ignite/Bootstrap grid classes while sharing the spacing scale. */
        .row.g-3 { --bs-gutter-x: var(--space-4); --bs-gutter-y: var(--space-4); }

        """
    }

    static var version: String {
        SHA256.hash(data: Data(stylesheet().utf8)).prefix(6)
            .map { String(("0" + String($0, radix: 16)).suffix(2)) }.joined()
    }

    /// SVGs cannot inherit page variables when loaded as images. Resolve their
    /// explicit paint bindings during publishing; fallbacks keep source previews valid.
    static func renderSVG(_ source: String, palette: BrandPalette = DesignTokens.palette) throws -> String {
        let colors = Dictionary(uniqueKeysWithValues: palette.properties)
        let pattern = try NSRegularExpression(pattern: #"var\(--([a-z-]+),\s*#[0-9a-fA-F]{6}\)"#)
        let matches = pattern.matches(in: source, range: NSRange(source.startIndex..., in: source))
        var result = source
        for match in matches.reversed() {
            let name = (source as NSString).substring(with: match.range(at: 1))
            guard let color = colors[name] else { throw TokenError.unknownColor(name) }
            result = (result as NSString).replacingCharacters(in: match.range, with: color)
        }
        guard !result.contains("var(--") else { throw TokenError.unknownColor("Unresolved SVG paint binding") }
        return result
    }

    static func install(in directory: URL) throws {
        try stylesheet().write(to: directory.appendingPathComponent("design-tokens.css"), atomically: true, encoding: .utf8)
        for name in brandAssetNames {
            let file = directory.appendingPathComponent(name)
            let source = try String(contentsOf: file, encoding: .utf8)
            try renderSVG(source).write(to: file, atomically: true, encoding: .utf8)
        }
    }

    enum TokenError: Error {
        case unknownColor(String)
    }
}
