import Ignite

extension Pages {
    var terms: MarketingPage {
        MarketingPage(path: "/terms/", title: "Terms and conditions", description: "How Sponsored by Indies works, our shared responsibilities, and how to resolve problems together.") {
            Components.breadcrumb([("Home", "/"), ("Terms and conditions", nil)])
            Tag("section") {
                Components.title("Terms and", emphasis: "conditions.")
                Text("Last updated: \(escaped(catalog.terms.updatedOn))")
                Text(escaped(catalog.terms.introduction)).class("lead")
            }.class("container", "page-intro")
            Tag("article") {
                for section in catalog.terms.sections {
                    Tag("section") {
                        Text(escaped(section.heading)).font(.title2)
                        for paragraph in section.paragraphs {
                            Text(escaped(paragraph))
                        }
                    }
                }
                if let contact = catalog.contactURL {
                    Text { Link("Contact Sponsored by Indies about these terms or a problem", target: contact) }
                }
            }.class("container", "section-space")
        }
    }
}
