import Ignite

extension Components {
    static func audienceBenefitCard(
        _ title: String,
        introduction: String,
        benefits: [String],
        actionLabel: String,
        target: String,
        style: ButtonStyle = .primary
    ) -> some HTML {
        Section {
            Tag("article") {
                VStack(alignment: .leading, spacing: nil) {
                    Text(escaped(title)).font(.title3)
                    Text(escaped(introduction))
                    List(benefits) { escaped($0) }
                    Section {
                        button(actionLabel, href: target, style: style)
                    }
                    .class("actions")
                    .margin(.top, .custom("auto"))
                    .padding(.top, .custom("var(--space-4)"))
                }.frame(height: .percent(100%))
            }.class("panel")
        }
        // Ignite has no stretch case for a Grid item's vertical alignment.
        .class("align-self-stretch")
    }
}
