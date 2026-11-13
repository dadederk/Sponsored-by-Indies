import Foundation
import Ignite

struct IndieContribution {
    let catalog: Catalog
    let date: Date

    var page: MarketingPage {
        MarketingPage(path: "/participate/indies/", title: "Contribute as an indie", description: "Share your indie work with an iOS, Swift or Apple platform developer conference community. Apps, games, books, courses, tools…") {
            Components.breadcrumb([("Get involved", "/participate/"), ("For indies", nil)])
            Tag("section") {
                Components.title("A little of", emphasis: "what you make.")
                Text("Share an app, game, book, course, tool… with a conference community you care about.").class("lead")
                Text("Help support an iOS, Swift or Apple developer conference. Contributions can be useful, playful or educational; they don’t have to be developer tools.")
                Text("Solo makers and small independent teams are welcome. This is an initial proposal; we can work out the details together, and you’ll approve the final profile and offer before publication.")
                if let contact = catalog.contactURL {
                    Components.button("Express indie interest", href: interestURL(contact))
                    if contact.hasPrefix("mailto:") {
                        Text("Opens an email draft. Share your conference, product link and proposed offer, or use the form below.").class("contact-note")
                    } else {
                        Text("Share your conference, product link and proposed offer through our contact page.").class("contact-note")
                    }
                }
            }.class("container", "page-intro")
            Section {
                if let contact = catalog.contactURL, let recipient = URLComponents(string: contact)?.path, contact.hasPrefix("mailto:") {
                    Text("Fill in the form to prepare an email, then review and send it in your email app.").id("form-help")
                    contributionForm(recipient: recipient).class("reading-width")
                    Tag("section") {
                        Text("Your email draft").font(.title2).id("draft-title")
                        Text("The email link includes your answers as text. To include selected images, download the email file instead. You can also copy the text and attach images yourself.")
                        Tag("label") { "Subject" }.attribute("for", "draft-subject").class("form-label")
                        Tag("input").id("draft-subject").attribute("type", "text").attribute("readonly").class("form-control")
                        FormFields.multiline("Email text", id: "draft-body", rows: 16, readOnly: true)
                        Section {
                            Link("Open email app", target: contact).linkStyle(.button).role(.primary).id("draft-email-link")
                            Button("Copy email text").type(.plain).role(.secondary).id("copy-draft")
                            // The browser supplies the download URL after preparing the file.
                            Tag("a") { "Download email file (.eml)" }.id("download-draft")
                                .attribute("download", "indie-contribution.eml").class("btn", "btn-secondary")
                        }.class("actions")
                        Text("Open the downloaded file in your email app. Depending on the app, you may need to choose Edit as new or Forward before sending.").class("field-help")
                        Text("").id("draft-attachment-note").class("field-help")
                        Text("Nothing has been sent. You choose when to send the email in your email app.").class("contact-note")
                    }.id("draft-preview").class("reading-width").attribute("hidden").aria(.labelledBy, "draft-title")
                    Tag("p") { "" }.id("form-status").attribute("role", "status").aria(.live, "polite")
                    Tag("noscript") {
                        Text("The email builder needs JavaScript. You can email us directly with your name, chosen conference, product links, and proposed offers instead.")
                    }
                    Text { "Prefer to write directly? "; Link(escaped(recipient), target: interestURL(contact)) }
                    Script(file: "/contribution.mjs").attribute("type", "module")
                } else if catalog.contactURL == nil {
                    Text("A contribution contact route will be available here soon.")
                } else {
                    Text("Use the contact page above to share your proposal.")
                }
            }.class("container", "section-space")
        }
    }

    private func interestURL(_ contact: String) -> String {
        Components.interestURL(contact, subject: "Sponsored by Indies — indie contribution", body: "Hi! I’d like to contribute to Sponsored by Indies.\r\n\r\nName:\r\nConference and year:\r\nProduct name and link:\r\nWhat I’d like to offer:\r\n\r\nMy connection to the conference (optional):\r\n\r\nAnything else you’d like us to know (optional):\r\n")
    }

    func contributionForm(recipient: String) -> some HTML {
        Form {
            Section("About you") {
                FormFields.field("Name", id: "maker-name", required: true, autocomplete: "name", placeholder: "Dani Devesa")
                FormFields.field("Contact email", id: "maker-email", type: .email, required: true, autocomplete: "email", limit: 254, placeholder: "hello@accessibilityupto11.com")
                Tag("details") {
                    Tag("summary") { "More about you (optional)" }
                    FormFields.textInput("Company or team (optional)", id: "maker-company", autocomplete: "organization", placeholder: "accessibilityUpTo11.com")
                    FormFields.textInput("Website (optional)", id: "maker-website", type: "url", autocomplete: "url", limit: 500, placeholder: "https://accessibilityupto11.com/")
                    FormFields.multiline("Social links you’d like shown (optional)", id: "maker-socials", rows: 2, limit: 800, placeholder: "https://github.com/dadederk")
                    FormFields.textInput("Photo, avatar or press-kit link (optional)", id: "maker-assets", type: "url", limit: 500)
                }
            }
            Section("Your conference") {
                FormFields.field("Conference you’d like to contribute to", id: "conference", required: true, list: "conference-options", helpID: "conference-help", placeholder: "ARCTIC 2027")
                Tag("datalist") {
                    for conference in catalog.conferences {
                        for label in catalog.editions(for: conference).filter({ $0.endDate >= date.formatted(Edition.dayStyle) }).map(\.label) {
                            Tag("option").attribute("value", escaped("\(conference.name) \(label)"))
                        }
                    }
                }.id("conference-options")
                Text("Choose a suggestion or type any conference and year.").id("conference-help").class("field-help")
                Tag("details") {
                    Tag("summary") { "Your connection and quote (optional)" }
                    FormFields.multiline("Your connection to this conference (optional)", id: "connection", limit: 700, helpID: "connection-help", placeholder: "I ran a workshop at the first edition.")
                    Text("Tell us how you’re connected (speaker, attendee, organiser…) and which year(s).").id("connection-help").class("field-help")
                    FormFields.multiline("A quote about what the conference means to you (optional)", id: "conference-quote", limit: 800, placeholder: "The quality took us by surprise for a first edition. Many of us came back the next year!")
                }
            }
            resource
            FormFields.actionButton("Add another app, game or other resource", icon: "plus-lg", role: .secondary).id("add-resource")
            Section("Prepare your email") {
                Text("A rough proposal is enough. We’ll agree plans, prices, dates and redemption details together later. Please don’t include private redemption codes.")
                Section {
                    Button("Open email draft").id("prepare-draft").type(.submit).role(.primary).customAttribute(name: "name", value: "draft-action").customAttribute(name: "value", value: "email")
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
        let section = Section("1. App, game or other resource") {
            Tag("details") {
                Tag("summary") { "Product details and icon (optional)" }
                FormFields.textInput("Product name (optional)", id: "resource-1-product", resourceKey: "product", placeholder: "Xarra!")
                FormFields.textInput("Product URL (optional)", id: "resource-1-url", type: "url", limit: 500, resourceKey: "url", placeholder: "https://accessibilityupto11.com/apps/xarra/")
                FormFields.multiline("What does it do, and who is it for? (optional)", id: "resource-1-description", limit: 500, resourceKey: "description", placeholder: "Turn articles, books and documents into audio with synchronized highlighting.")
                Section {
                    Tag("label") { "App icon or product image (optional)" }.attribute("for", "resource-1-icon").class("form-label")
                    Tag("input").id("resource-1-icon").attribute("name", "resource-1-icon").attribute("type", "file")
                        .attribute("accept", "image/png,image/jpeg,image/webp")
                        .attribute("data-product-icon", "true").aria(.describedBy, "resource-1-icon-help").class("form-control")
                    FormFields.actionButton("Remove image", icon: "trash", role: .secondary)
                        .customAttribute(name: "data-remove-icon", value: "true")
                        .customAttribute(name: "aria-label", value: "Remove image from contribution 1")
                        .customAttribute(name: "hidden", value: "hidden")
                    Text("PNG, JPEG or WebP. Max 5 MB each, 10 MB total. To send images, download the email file or attach them in your email app.")
                        .id("resource-1-icon-help").class("field-help")
                }
            }
            offer
            Section {
                FormFields.actionButton("Add another offer", icon: "plus-lg", role: .secondary)
                    .customAttribute(name: "data-add-offer", value: "true")
                    .customAttribute(name: "aria-label", value: "Add another offer to contribution 1")
                FormFields.actionButton("Remove contribution 1", icon: "trash", role: .danger).customAttribute(name: "data-remove-resource", value: "true").customAttribute(name: "hidden", value: "hidden")
            }.class("actions")
        }
        return section.customAttribute(name: "id", value: "resource-1").customAttribute(name: "data-resource", value: "true")
    }

    var offer: some HTML {
        Tag("fieldset") {
            Tag("legend") { "1. Offer" }
            FormFields.multiline("What would you like to offer? (required)", id: "resource-1-offer-1-proposal", rows: 3, required: true, limit: 3000, resourceKey: "proposal", helpID: "resource-1-offer-1-proposal-help", placeholder: "Get 50% off lifetime Premium for Xarra! at ARCTIC 2027: https://accessibilityupto11.com/apps/xarra/")
            Text("Include the name and a link. Plain text or Markdown is fine.")
                .id("resource-1-offer-1-proposal-help").class("field-help")
            FormFields.actionButton("Remove offer 1", icon: "trash", role: .danger).customAttribute(name: "data-remove-offer", value: "true").customAttribute(name: "hidden", value: "hidden")
        }.id("resource-1-offer-1").attribute("data-offer", "true")
    }

}
