import Ignite

extension Pages {
    var participate: MarketingPage {
        MarketingPage(path: "/participate/", title: "Get involved", description: "Bring a bundle to your iOS, Swift or Apple developer conference, contribute an indie project, or find what’s included with your ticket.") {
            Components.breadcrumb([("Home", "/"), ("Get involved", nil)])
            Tag("section") {
                Components.title("Get", emphasis: "involved.")
                Text("Bring a bundle to your iOS, Swift or Apple developer conference, share what you make, or find what’s included with your ticket.").class("lead")
            }.class("container", "page-intro")
            Section {
                Components.audienceBenefitCards(for: [.conferences, .indies, .attendees], titleStyle: .title2)
            }.class("container", "section-space")
        }
    }
}
