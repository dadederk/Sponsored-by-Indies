import Ignite

extension Components {
    static func participationPanels(
        @HTMLBuilder first: () -> some HTML, @HTMLBuilder second: () -> some HTML
    ) -> some HTML {
        Section {
            Grid(alignment: .top, spacing: .none) {
                Section { first() }.class("align-self-stretch")
                Section { second() }.class("align-self-stretch")
            }.columns(1).class("partnership-panels", "g-3", "row-cols-lg-2")
        }.class("container", "section-space")
    }

    static func participationPanel(
        _ title: String, emphasis: String, id: String, @HTMLBuilder content: @escaping () -> some HTML
    ) -> some HTML {
        Tag("section") {
            heading(title, emphasis, id: id)
            content()
        }.class("panel").aria(.labelledBy, id)
    }

    static func processSection(
        _ title: String, emphasis: String, id: String, steps: [(title: String, description: String)]
    ) -> some HTML {
        Tag("section") {
            Section {
                heading(title, emphasis, id: id)
                processSteps(steps)
            }.class("container", "section-space")
        }.class("tinted-section").aria(.labelledBy, id)
    }

    static func emailDraftPreview(contact: String, filename: String, includesImages: Bool = false) -> some HTML {
        Tag("section") {
            Text("Your email draft").font(.title2).id("draft-title")
            if includesImages {
                Text("The email link includes your answers as text. To include selected images, download the email file instead. You can also copy the text and attach images yourself.")
            } else {
                Text("Review your answers, then open the draft in your email app to send it. You can also copy the text or download an email file.")
            }
            Tag("label") { "Subject" }.attribute("for", "draft-subject").class("form-label")
            Tag("input").id("draft-subject").attribute("type", "text").attribute("readonly").class("form-control")
            FormFields.multiline("Email text", id: "draft-body", rows: 16, readOnly: true)
            Section {
                Link("Open email app", target: contact).linkStyle(.button).role(.primary).id("draft-email-link")
                Button("Copy email text").type(.plain).role(.secondary).id("copy-draft")
                Tag("a") { "Download email file (.eml)" }.id("download-draft")
                    .attribute("download", filename).class("btn", "btn-secondary")
            }.class("actions")
            Text("Open the downloaded file in your email app. Depending on the app, you may need to choose Edit as new or Forward before sending.").class("field-help")
            Text("").id("draft-attachment-note").class("field-help").attribute("hidden")
            Text("Nothing has been sent. You choose when to send the email in your email app.").class("contact-note")
        }.id("draft-preview").class("reading-width").attribute("hidden").aria(.labelledBy, "draft-title")
    }

    static var emailDraftActions: some HTML {
        Section {
            Button("Open email draft").id("prepare-draft").type(.submit).role(.primary)
                .customAttribute(name: "name", value: "draft-action").customAttribute(name: "value", value: "email")
            Button("Preview email first").type(.submit).role(.secondary)
                .customAttribute(name: "name", value: "draft-action").customAttribute(name: "value", value: "preview")
        }.class("actions")
    }

    static var emailFormFallback: some HTML {
        Text("The form needs JavaScript. You can use the email button above to get in touch instead.")
            .id("form-fallback").class("field-help")
    }

    static var emailFormStatus: some HTML {
        Tag("p") { "" }.id("form-status").attribute("role", "status").aria(.live, "polite")
    }
}
