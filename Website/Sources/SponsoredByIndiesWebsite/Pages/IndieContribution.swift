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
                        Text("The email link includes the recipient, subject and all your answers. If your app cannot open a long draft, download the complete email file instead, or copy the text below.")
                        Tag("label") { "Subject" }.attribute("for", "draft-subject").class("form-label")
                        Tag("input").id("draft-subject").attribute("type", "text").attribute("readonly").class("form-control")
                        FormFields.multiline("Email text", id: "draft-body", rows: 16, readOnly: true)
                        Section {
                            Button("Copy email text").type(.plain).role(.secondary).id("copy-draft")
                            Link("Open email app", target: contact).id("draft-email-link")
                            Tag("a") { "Download email file (.eml)" }.id("download-draft").attribute("download", "indie-contribution.eml")
                        }.class("actions")
                        Text("Open the downloaded file in your email app. Depending on the app, you may need to choose Edit as new or Forward before sending.").class("field-help")
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
            FormFields.actionButton("Add another resource", icon: "plus-lg", role: .secondary).id("add-resource")
            Section("Prepare your email") {
                Text("Add as many offers as you like to each resource. Free access is selected to start; optional details can follow later. Please share asset links rather than redemption codes.")
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
            offer
            Section {
                FormFields.actionButton("Add another offer", icon: "plus-lg", role: .secondary).customAttribute(name: "data-add-offer", value: "true")
                FormFields.actionButton("Remove resource 1", icon: "trash", role: .danger).customAttribute(name: "data-remove-resource", value: "true").customAttribute(name: "hidden", value: "hidden")
            }.class("actions")
        }
        return section.customAttribute(name: "id", value: "resource-1").customAttribute(name: "data-resource", value: "true")
    }

    var offer: some HTML {
        Tag("fieldset") {
            Tag("legend") { "Offer 1" }
            select("Offer type", key: "kind", options: ["Free", "Percentage discount", "Fixed discount", "Other"])
            Section {
                FormFields.textInput("Discount or offer details (required)", id: "resource-1-offer-1-discount", limit: 300, resourceKey: "discount", helpID: "resource-1-offer-1-discount-help")
                Text("For example: 50%, GBP 10 off, or your proposed terms.").id("resource-1-offer-1-discount-help").class("field-help")
            }.attribute("data-discount-details", "true").attribute("hidden")
            select("Who can receive this offer?", key: "audience", options: ["Every eligible attendee", "Limited prize licenses"])
            Section {
                Tag("label") { "Number of prize licenses (required)" }.attribute("for", "resource-1-offer-1-quantity").class("form-label")
                Tag("input").id("resource-1-offer-1-quantity").attribute("name", "resource-1-offer-1-quantity")
                    .attribute("type", "number").attribute("min", "1").attribute("step", "1")
                    .attribute("data-resource-field", "quantity").attribute("disabled").class("form-control")
                Text("We’ll agree the raffle or selection process with you and the organiser.").class("field-help")
            }.attribute("data-prize-details", "true").attribute("hidden")
            Tag("details") {
                Tag("summary") { "Plan, price and dates (optional)" }
                FormFields.textInput("Product edition or plan (optional)", id: "resource-1-offer-1-plan", resourceKey: "plan", helpID: "resource-1-offer-1-plan-help")
                Text("For example: Pro annual plan, lifetime unlock, or digital edition.").id("resource-1-offer-1-plan-help").class("field-help")
                FormFields.textInput("Usual price and currency (optional)", id: "resource-1-offer-1-price", resourceKey: "regularPrice", helpID: "resource-1-offer-1-price-help")
                Text("For example: GBP 1.99 once, USD 9.99/year, or EUR 29.99 for lifetime access. Include a billing period only for subscriptions.").id("resource-1-offer-1-price-help").class("field-help")
                FormFields.textInput("How long does access last? (optional)", id: "resource-1-offer-1-duration", resourceKey: "duration", helpID: "resource-1-offer-1-duration-help")
                Text("For example: lifetime, one year, or three months. This is separate from the deadline to claim the offer.").id("resource-1-offer-1-duration-help").class("field-help")
                Tag("label") { "Valid until / last day to claim (optional)" }.attribute("for", "resource-1-offer-1-valid-until").class("form-label")
                Tag("input").id("resource-1-offer-1-valid-until").attribute("name", "resource-1-offer-1-valid-until")
                    .attribute("type", "date").attribute("data-resource-field", "validUntil").class("form-control")
                FormFields.multiline("Conditions and redemption (optional)", id: "resource-1-offer-1-conditions", rows: 3, limit: 1600, resourceKey: "conditions", helpID: "resource-1-offer-1-conditions-help")
                Text("If relevant: customer eligibility, regions/platforms, renewal terms, claim deadline time zone, how to redeem, or whether attendees must choose between your offers.").id("resource-1-offer-1-conditions-help").class("field-help")
            }
            FormFields.actionButton("Remove offer 1", icon: "trash", role: .danger).customAttribute(name: "data-remove-offer", value: "true").customAttribute(name: "hidden", value: "hidden")
        }.id("resource-1-offer-1").attribute("data-offer", "true")
    }

    func select(_ label: String, key: String, options: [String]) -> some HTML {
        let id = "resource-1-offer-1-\(key)"
        return Section {
            Tag("label") { escaped(label) }.attribute("for", id).class("form-label")
            Tag("select") {
                for option in options {
                    Tag("option") { escaped(option) }.attribute("value", option)
                }
            }.id(id).attribute("name", id).attribute("data-resource-field", key).class("form-select")
        }
    }
}
