import Foundation
import Ignite

extension Components {
    static func projectHeading(_ name: String, url: String, icon: String?, level: Font.Style = .title3) -> some HTML {
        Text {
            Link(target: escaped(url)) {
                if let icon {
                    Image(decorative: icon)
                        .frame(width: .px(DesignTokens.productIconSize), height: .px(DesignTokens.productIconSize))
                        .cornerRadius(DesignTokens.productIconRadius)
                }
                Span {
                    Span(escaped(name)).class("product-card-title")
                    if let host = URL(string: url)?.host {
                        Span(escaped(host)).font(.small).fontWeight(.regular)
                            .foregroundStyle(.secondary).class("product-card-url")
                    }
                }.class("product-card-name")
            }.frame(width: .percent(100%))
        }.font(level).margin(0).class("product-card-heading")
    }
}
