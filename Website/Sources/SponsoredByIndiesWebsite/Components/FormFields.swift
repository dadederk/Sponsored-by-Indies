import Ignite

enum FormFields {
    static func actionButton(_ label: String, icon: String, role: Role) -> Button {
        Button {
            Image(systemName: icon, description: "").aria(.hidden, "true")
            Span(" ")
            Span(escaped(label)).customAttribute(name: "data-action-label", value: "true")
        }.type(.plain).role(role)
    }

    // Ignite's Form cannot apply label placement through a native Tag boundary.
    static func textInput(
        _ label: String, id: String, type: String = "text", autocomplete: String = "off",
        limit: Int = 160, resourceKey: String? = nil, helpID: String? = nil, placeholder: String? = nil
    ) -> some HTML {
        var control = AnyHTML(Tag("input").id(id).attribute("name", id).attribute("type", type)
            .attribute("maxlength", String(limit)).attribute("autocomplete", autocomplete)
            .aria(.describedBy, helpID).class("form-control"))
        if let resourceKey { control = AnyHTML(control.attribute("data-resource-field", resourceKey)) }
        if let placeholder { control = AnyHTML(control.attribute("placeholder", escaped(placeholder))) }
        return Section {
            Tag("label") { escaped(label) }.attribute("for", id).class("form-label")
            control
        }.class("form-field")
    }

    static func field(
        _ label: String, id: String, type: TextField.TextType = .text, required: Bool = false, autocomplete: String = "off",
        limit: Int = 160, list: String? = nil, resourceKey: String? = nil, helpID: String? = nil, placeholder: String? = nil
    ) -> TextField {
        var field = TextField(escaped(label + (required ? " (required)" : "")), prompt: placeholder.map(escaped))
            .id(id).type(type)
            .customAttribute(name: "name", value: id)
            .customAttribute(name: "autocomplete", value: autocomplete)
            .customAttribute(name: "maxlength", value: String(limit))
        if required { field = field.required() }
        if let list { field = field.customAttribute(name: "list", value: list) }
        if let resourceKey { field = field.customAttribute(name: "data-resource-field", value: resourceKey) }
        if let helpID { field = field.customAttribute(name: "aria-describedby", value: helpID) }
        return field
    }

    static func multiline(
        _ label: String, id: String, rows: Int = 3, required: Bool = false, readOnly: Bool = false, limit: Int = 20000,
        resourceKey: String? = nil, helpID: String? = nil, placeholder: String? = nil
    ) -> some HTML {
        // Erase the control type locally so independent conditional modifiers compose.
        var control = AnyHTML(
            Tag("textarea").id(id).attribute("name", id)
                .attribute("rows", String(rows)).attribute("maxlength", String(limit))
                .class("form-control").aria(.describedBy, helpID)
        )
        if required { control = AnyHTML(control.attribute("required")) }
        if readOnly { control = AnyHTML(control.attribute("readonly")) }
        if let resourceKey { control = AnyHTML(control.attribute("data-resource-field", resourceKey)) }
        if let placeholder { control = AnyHTML(control.attribute("placeholder", escaped(placeholder))) }
        return Section {
            Tag("label") { escaped(label) }.attribute("for", id).class("form-label")
            control
        }.class("form-field")
    }
}
