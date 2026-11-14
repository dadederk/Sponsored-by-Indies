import Foundation
import Ignite

extension Components {
    static func showcaseCard(
        _ project: Project, indie: Indie, editions: [Edition], catalog: Catalog,
        date: Date, sponsoredRoot: String
    ) -> some HTML {
        let people = indie.people ?? [IndiePerson(name: indie.name, websiteURL: indie.websiteURL, socials: indie.socials)]
        let today = date.formatted(Edition.dayStyle)
        return Tag("article") {
            projectHeading(project.name, url: project.websiteURL, icon: project.iconPath, level: .title2)
                .class("showcase-project-title")
            Text(escaped(project.showcaseDescription)).margin(0)
            Section {
                Text(people.count == 1 ? "Meet the builder" : "Meet the builders")
                    .font(.title3).margin(.bottom, .small)
                for person in people { builderRow(person) }
            }.class("showcase-builders")
            Section {
                Text("Find it in a conference bundle").fontWeight(.semibold).margin(.bottom, .small)
                List(editions) { edition in
                    let timing = edition.endDate < today ? "Past conference" : edition.startDate > today ? "Upcoming conference" : "Current conference"
                    return ListItem {
                        Link(
                            escaped(catalog.conference(for: edition).name + " " + edition.label) + " bundle",
                            target: escaped(sponsoredRoot + edition.path(in: catalog) + "#" + project.bundleAnchor))
                        Span(" · " + timing)
                            .font(.small).foregroundStyle(.secondary)
                    }
                }.margin(0).class("showcase-bundles")
            }.class("showcase-contributions")
        }.id(project.bundleAnchor).class("panel", "showcase-card")
    }

    private static func builderRow(_ person: IndiePerson) -> some HTML {
        HStack(alignment: .top, spacing: .medium) {
            if let portrait = person.portraitPath {
                Image(decorative: portrait)
                    .frame(width: .px(DesignTokens.builderPortraitSize), height: .px(DesignTokens.builderPortraitSize))
                    .cornerRadius(DesignTokens.builderPortraitSize / 2)
                    .attribute("loading", "lazy").attribute("width", String(DesignTokens.builderPortraitSize))
                    .attribute("height", String(DesignTokens.builderPortraitSize))
                    .class("builder-portrait")
            } else {
                Text(escaped(person.initials)).fontWeight(.semibold).margin(0)
                    .frame(width: .px(DesignTokens.builderPortraitSize), height: .px(DesignTokens.builderPortraitSize))
                    .cornerRadius(DesignTokens.builderPortraitSize / 2)
                    .background(Color(hex: DesignTokens.palette.tint)).foregroundStyle(Color(hex: DesignTokens.palette.blue))
                    .aria(.hidden, "true").class("builder-initials")
            }
            Section {
                Text(escaped(person.name)).fontWeight(.semibold).margin(0)
                if let bio = person.bio { Text(escaped(bio)).font(.small).margin(0) }
                Section {
                    for link in person.showcaseLinks { builderLink(link.label, for: person.name, to: link.url) }
                }.font(.small).class("builder-links")
            }
        }.class("builder-row")
    }

    private static func builderLink(_ label: String, for name: String, to url: String) -> some InlineElement {
        Link(target: escaped(url)) {
            escaped(label)
            Span(" for " + escaped(name)).class("visually-hidden")
        }
    }
}
