import Foundation
import Ignite

struct IndieContribution {
    let catalog: Catalog

    var page: MarketingPage {
        MarketingPage(path: "/participate/indies/", title: "Contribute as an indie", description: "Share your indie work with an iOS, Swift or Apple platform developer conference community. Apps, games, books, courses, tools…") {
            Components.breadcrumb([("Get involved", "/participate/"), ("For indies", nil)])
            Tag("section") {
                Components.title("A little of", emphasis: "what you make.")
                Text("Share an app, game, book, course, tool… with a conference community you care about.").class("lead")
                Text("Help support an iOS, Swift or Apple developer conference. Contributions can be useful, playful or educational; they don’t have to be developer tools.")
                Text("Solo makers and small independent teams are welcome. This is an initial proposal; we can work out the details together, and you’ll approve the final profile and offer before publication.")
            }.class("container", "page-intro")
            Section {
                if let contact = catalog.contactURL, let recipient = URLComponents(string: contact)?.path, contact.hasPrefix("mailto:") {
                    Text("Fill in the form, then open an email draft to review and send. Your answers aren’t submitted to this website or saved between visits.").id("form-help")
                    Text("Fields labelled “required” are needed to prepare the draft. Everything else can follow later.")
                    contributionForm(recipient: recipient).class("reading-width")
                    Tag("section") {
                        Text("Your email draft").font(.title2).id("draft-title")
                        Text("Check your answers below. If your email app doesn’t open, copy the text and paste it into an email.")
                        Tag("label") { "Subject" }.attribute("for", "draft-subject").class("form-label")
                        Tag("input").id("draft-subject").attribute("type", "text").attribute("readonly").class("form-control")
                        FormFields.multiline("Email text", id: "draft-body", rows: 16, readOnly: true)
                        Section {
                            Button("Copy email text").type(.plain).role(.secondary).id("copy-draft")
                            Link("Open email app", target: contact).id("draft-email-link")
                        }.class("actions")
                        Text("Nothing has been sent. You choose when to send the email in your email app.").class("contact-note")
                    }.id("draft-preview").class("reading-width").attribute("hidden").aria(.labelledBy, "draft-title")
                    Tag("p") { "" }.id("form-status").attribute("role", "status").aria(.live, "polite")
                    Tag("noscript") {
                        Text("The email builder needs JavaScript. You can email us directly with your name, conference connection, product links, and proposed offers instead.")
                    }
                    Text { "Prefer to write directly? "; Link(escaped(recipient), target: Components.interestURL(contact, subject: "Sponsored by Indies — indie contribution")) }
                    Script(file: "/contribution.mjs").attribute("type", "module")
                } else {
                    Text("A contribution contact route will be available here soon.")
                }
            }.class("container", "section-space")
        }
    }

    func contributionForm(recipient: String) -> some HTML {
        Form {
            Section("About you") {
                FormFields.field("Name", id: "maker-name", required: true, autocomplete: "name")
                FormFields.field("Contact email", id: "maker-email", type: .email, required: true, autocomplete: "email", limit: 254)
                FormFields.field("Company or team (optional)", id: "maker-company", autocomplete: "organization")
                FormFields.field("Website (optional)", id: "maker-website", type: .url, autocomplete: "url", limit: 500)
                FormFields.multiline("Social links you’d like shown (optional)", id: "maker-socials", rows: 2, limit: 800)
                FormFields.field("Photo, avatar or press-kit link (optional)", id: "maker-assets", type: .url, limit: 500)
            }
            Section("Your conference connection") {
                FormFields.field("Conference and edition", id: "conference", required: true, list: "conference-options", helpID: "conference-help")
                Tag("datalist") {
                    for conference in catalog.conferences {
                        for label in conference.connectionEditions ?? catalog.editions(for: conference).map(\.label) {
                            Tag("option").attribute("value", escaped("\(conference.name) \(label)"))
                        }
                    }
                }.id("conference-options")
                Text("Choose an edition you’re connected to, or type another conference and edition. You can mention other years in your connection below.").id("conference-help").class("field-help")
                FormFields.multiline("Your connection to this conference (required)", id: "connection", required: true, limit: 700)
                FormFields.multiline("A quote about what the conference means to you (optional)", id: "conference-quote", limit: 800)
            }
            resource
            Button("Add another resource").type(.plain).role(.secondary).id("add-resource")
            Section("Prepare your email") {
                Text("You can propose free access or a discount, and leave details open for discussion. Please share asset links rather than redemption codes.")
                Section {
                    Button("Open email draft").type(.submit).role(.primary).customAttribute(name: "name", value: "draft-action").customAttribute(name: "value", value: "email")
                    Button("Preview email first").type(.submit).role(.secondary).customAttribute(name: "name", value: "draft-action").customAttribute(name: "value", value: "preview")
                }.class("actions")
            }
        }
        .labelStyle(.top)
        .id("contribution-form")
        .class("contribution-form")
        .attribute("data-recipient", escaped(recipient))
        .attribute("hidden")
        .aria(.describedBy, "form-help")
    }

    var resource: Section {
        let section = Section("Resource 1") {
            FormFields.field("Product or resource name", id: "resource-1-product", required: true, resourceKey: "product")
            FormFields.field("Product URL", id: "resource-1-url", type: .url, required: true, limit: 500, resourceKey: "url")
            Section {
                Tag("label") { "Type (required)" }.attribute("for", "resource-1-category").class("form-label")
                Tag("select") {
                    Tag("option") { "Choose a type" }.attribute("value", "")
                    for type in ["App", "Game", "Book", "Course", "Developer tool", "Other"] {
                        Tag("option") { escaped(type) }.attribute("value", type)
                    }
                }.id("resource-1-category").attribute("name", "resource-1-category").attribute("data-resource-field", "category").attribute("required").class("form-select")
            }
            FormFields.multiline("What does it do, and who is it for? (required)", id: "resource-1-description", required: true, limit: 500, resourceKey: "description")
            FormFields.multiline("What would you like to offer? (required)", id: "resource-1-offer", required: true, limit: 800, resourceKey: "offer", helpID: "resource-1-offer-help")
            Text("For example: free access, a percentage discount, or a free subscription period. Tell us the product/plan and duration if you know them.").id("resource-1-offer-help").class("field-help")
            FormFields.field("Standard price, currency and billing period (optional)", id: "resource-1-regular-price", limit: 120, resourceKey: "regularPrice")
            FormFields.field("Attendee price or discount (optional)", id: "resource-1-attendee-price", limit: 120, resourceKey: "attendeePrice")
            FormFields.multiline("Availability and redemption details (optional)", id: "resource-1-conditions", rows: 4, limit: 1600, resourceKey: "conditions", helpID: "resource-1-conditions-help")
            Text("If known: capacity for all attendees, new/existing customer eligibility, regions/platforms, redemption method and deadline, access duration, renewal terms, and any mutually exclusive offers.").id("resource-1-conditions-help").class("field-help")
            Button("Remove resource 1").type(.plain).role(.secondary).customAttribute(name: "data-remove-resource", value: "true").customAttribute(name: "hidden", value: "hidden")
        }
        return section.customAttribute(name: "id", value: "resource-1").customAttribute(name: "data-resource", value: "true")
    }
}
