import Ignite

extension Components {
    static func processSteps(_ steps: [(title: String, description: String)]) -> some HTML {
        List(steps) { step in
            ListItem {
                Text(escaped(step.title)).font(.title3)
                Text(escaped(step.description))
            }
        }.listMarkerStyle(.ordered).class("steps")
    }
}
