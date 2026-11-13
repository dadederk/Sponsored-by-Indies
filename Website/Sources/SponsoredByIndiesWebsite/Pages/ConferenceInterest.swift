import Foundation
import Ignite

struct ConferenceInterest {
    let catalog: Catalog

    var page: MarketingPage {
        MarketingPage(path: "/participate/conferences/", title: "For conference organisers", description: "Indie bundles for iOS, Swift and Apple platform developer conferences: the benefits, partnership, and how to express interest.") {
            Components.breadcrumb([("Get involved", "/participate/"), ("For conferences", nil)])
            Tag("section") {
                Components.title("More value.", emphasis: "Made together.")
                Text("Let indie makers help you offer more value with every ticket to your iOS, Swift or Apple developer conference.").class("lead")
                if let note = catalog.partnershipNote { Text(escaped(note)) }
                if let contact = catalog.contactURL {
                    Components.button("Express conference interest", href: interestURL(contact))
                    if contact.hasPrefix("mailto:") {
                        Text("Opens an email draft. Tell us about your conference, or use the form below.").class("contact-note")
                    } else {
                        Text("Tell us about your conference through our contact page.").class("contact-note")
                    }
                }
            }.class("container", "page-intro")
            Components.participationPanels {
                partnershipBenefits
            } second: {
                partnershipRequests
            }
            partnershipProcess
            enquirySection
        }
    }

    private var partnershipBenefits: some HTML {
        Components.participationPanel("What your", emphasis: "conference gets.", id: "benefits-title") {
            List {
                ListItem {
                    Text("An extra for every attendee.").font(.title3)
                    Text("A bundle of free products and discounts on apps, games, books, courses, tools… from independent makers connected to your event.")
                }
                ListItem {
                    Text("A clearer ticket proposition.").font(.title3)
                    Text("Confirmed contributions and maximum potential savings you can include in your ticket messaging. Something tangible to help people see what they’re getting.")
                }
                ListItem {
                    Text("A bundle brought together.").font(.title3)
                    Text("We coordinate contributors and prepare an edition page with the makers, offers, terms, and attendee instructions. We work with you on the delivery plan.")
                }
            }.margin(.bottom, 0)
        }
    }

    private var partnershipRequests: some HTML {
        Components.participationPanel("What we ask", emphasis: "in return.", id: "asks-title") {
            List {
                ListItem {
                    Text("Modest sponsor recognition.").font(.title3)
                    Text("A lower-tier place for Sponsored by Indies, keeping recognition proportionate and leaving the spotlight for sponsors contributing money.")
                }
                ListItem {
                    Text("A website link and an opening slide.").font(.title3)
                    Text("Link to your edition’s bundle and showcase its indie contributors during the conference opening.")
                }
                ListItem {
                    Text("Help reaching ticket holders.").font(.title3)
                    Text("Confirm eligibility and attendee numbers with us, help choose a practical delivery method, and get access to everyone included, including later ticket buyers.")
                }
            }.margin(.bottom, 0)
        }
    }

    private var partnershipProcess: some HTML {
        Components.processSection("How we", emphasis: "put it together.", id: "process-title", steps: [
            ("Plan your edition.",
             "Tell us about your conference and its community. Together, we agree the scope, recognition, timing, and how attendees will get access."),
            ("Bring in your indies.",
             "Bring in connected indie makers and confirm their offers, capacity, and public profiles."),
            ("Share the bundle.",
             "Share the confirmed bundle, deliver access to ticket holders, and learn from the edition together."),
        ])
    }

    private var enquirySection: some HTML {
        Section {
            if let contact = catalog.contactURL, contact.hasPrefix("mailto:"), let recipient = URLComponents(string: contact)?.path {
                Tag("details") {
                    Tag("summary") { "Prefer a form?" }
                    Text("Tell us what you know so far. The form prepares an email for you to review and send in your email app.").id("form-help")
                    Components.emailFormFallback
                    enquiryForm(recipient: recipient).class("reading-width")
                    Components.emailDraftPreview(contact: contact, filename: "conference-interest.eml")
                    Components.emailFormStatus
                }.id("interest-form").class("participation-form")
                Script(file: "/conference-interest.mjs").attribute("type", "module")
            } else if catalog.contactURL == nil {
                Text("A conference contact route will be available here soon.")
            } else {
                Text("Use the contact page above to tell us about your conference.")
            }
        }.class("container", "section-space")
    }

    private func interestURL(_ contact: String) -> String {
        Components.interestURL(contact, subject: "Sponsored by Indies — conference interest", body: "Hi! I’d like to explore Sponsored by Indies for our conference.\r\n\r\nName:\r\nContact email:\r\nConference and website:\r\nNext edition and dates (optional):\r\nLocation (optional):\r\nApproximate attendee numbers (optional):\r\nAnything else we should know (optional):\r\n")
    }

    private func enquiryForm(recipient: String) -> some HTML {
        Form {
            Section("About you") {
                FormFields.field("Name", id: "organiser-name", required: true, autocomplete: "name")
                FormFields.field("Contact email", id: "organiser-email", type: .email, required: true, autocomplete: "email", limit: 254)
            }
            Section("Your conference") {
                FormFields.field("Conference name", id: "conference-name", required: true)
                FormFields.field("Website (optional)", id: "conference-website", type: .url, limit: 500)
                FormFields.field("Next edition and dates (optional)", id: "conference-dates", placeholder: "February 2027, dates to be confirmed")
                FormFields.field("Location (optional)", id: "conference-location", placeholder: "Oulu, Finland")
                FormFields.field("Approximate attendee numbers (optional)", id: "conference-attendees", limit: 80, placeholder: "Around 200, or still to be confirmed")
                FormFields.multiline("Anything else you’d like us to know (optional)", id: "conference-message", limit: 3000)
            }
            Section("Prepare your email") {
                Text("An initial enquiry is enough. We can work out the partnership details together.")
                Components.emailDraftActions
            }
        }.labelStyle(.top).id("conference-interest-form").class("contribution-form")
            .attribute("data-recipient", escaped(recipient)).attribute("hidden").aria(.describedBy, "form-help")
    }
}
