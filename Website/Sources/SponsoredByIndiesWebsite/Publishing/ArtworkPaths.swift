/// Relative paths shared by renderers, page metadata and downloadable exports.
enum ArtworkPaths {
    static let mark = "assets/brand/shared/by-indies-mark.svg"
    static let inverseMark = "assets/brand/shared/by-indies-mark-inverse.svg"
    static let favicon = "assets/icons/favicon.svg"
    static let faviconPNG = "assets/icons/favicon-32.png"

    static let vectorAssets = [
        "logo.svg": mark,
        "logo-inverse.svg": inverseMark,
        "favicon.svg": favicon
    ]

    static func brandDirectory(for identity: SiteIdentity) -> String {
        "assets/brand/" + (identity == .sponsored ? "sponsored-by-indies" : "by-indies")
    }

    static func brandFile(_ name: String, for identity: SiteIdentity = .sponsored) -> String {
        let prefix = identity == .sponsored ? "sponsored-by-indies" : "by-indies"
        return brandDirectory(for: identity) + "/\(prefix)-\(name).png"
    }

    static func conferenceDirectory(_ conference: Conference, edition: Edition) -> String {
        "assets/social/\(conference.slug)/\(edition.slug)"
    }

    static func partnerDirectory(_ conference: Conference, edition: Edition) -> String {
        conferenceDirectory(conference, edition: edition) + "/partners"
    }
}
