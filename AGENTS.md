# Sponsored by Indies conventions

Read [README.md](README.md) for the project structure, local preview and verification commands. This is a Swift/Ignite static site. Ignite resembles SwiftUI but is a separate framework; check the pinned source in `Website/.build/checkouts/Ignite` before assuming an API exists.

## Keep it simple

- Keep the README and contributor explanations concise and in plain English. Explain unfamiliar tools when first introduced.
- Keep public documentation focused on using and contributing to the website. Leave internal planning, correspondence, repository-migration history and operational notes out of the README.
- Prefer Ignite components and semantic modifiers to Bootstrap utility classes, inline styles, custom CSS or JavaScript.
- Use semantic HTML. Use `Tag` where Ignite has no suitable element and preserve native keyboard and browser behaviour.
- Keep pages focused on composition, shared UI in `Components`, content models and validation in `Models`, and build concerns in `Publishing`.
- Extract repeated behaviour with a clear purpose. Use descriptive names, small functions and comments that explain decisions or invariants. Avoid speculative abstractions and comments that repeat the code.
- Keep `AnyHTML` at necessary heterogeneous boundaries, such as the page registry.
- CSS exceptions need a reason: shared fluid layouts, inherited conference variables, descendant/state selectors or accessibility media queries. Preserve these when they express shared behaviour clearly.
- Site colours, spacing and dimensions belong in `DesignTokens.swift`. Components and CSS consume those values. Brand SVG paints use palette variables with preview fallbacks and are resolved during generation; conference palettes stay in their JSON records.
- After changing the logo, palette or artwork renderer, rebuild the site and copy `Website/Build/readme-banner.png` to `Images/readme-banner.png` to refresh the README banner.
- Limit JavaScript to progressive enhancements Ignite cannot provide. Preserve direct email and static-content fallbacks. Use the HTML `hidden` attribute where browser modules toggle `element.hidden`; Ignite's `.hidden()` generates a class instead.

## Public content boundaries

- Editorial input comes only from `Website/Data`. Every record in this repository must be approved for public release, even if rendering would omit it.
- Keep private planning, correspondence, contacts, attendee records, restricted codes and unapproved contributions in private storage. Never copy private repository history or Git metadata into this repository.
- Run `swift Scripts/CheckPublicRepository.swift` before committing. Its allowlist permits `README.md` and this curated `AGENTS.md`; other Markdown and internal documentation remain excluded. Extend the allowlist only for an explicitly reviewed public file.
- Keep conference identity, editions, participation and offers in separate per-conference records. Share maker identities through `indies.json`.
- IDs and routes are stable; changing a label must not rename an existing route. A new conference or edition should require data changes only. Keep conference branding and edition-specific wording out of Swift and CSS.
- Approval belongs to each edition's participation and offer. Never carry approval or discounts across years. An approved offer requires approved participation in the same edition.
- Load and validate all content before resolving references or rendering. Fail on invalid content and escape editorial plain text at the Ignite rendering boundary.
- Keep typed relational data in JSON. Use Ignite's supported content pipeline if substantial editorial Markdown is later needed; review its public-file boundary explicitly and avoid a custom front-matter parser.

## Accessibility and verification

- Preserve one main landmark and H1, heading order, skip navigation, labelled controls, native validation and visible keyboard focus.
- Preserve reflow, reduced-motion and forced-colour support. Keep interactive targets at least 44×44 CSS pixels and check contrast when changing colours.
- After a coherent change, run the Swift tests, preview/public generation and Node checks listed in the README, as well as the public repository check.
- Add meaningful regression tests for approval, validation, dates, links and other behaviour changes. Use Swift Testing for Swift tests; avoid tests that merely reproduce styling or implementation details.
- Prefer Swift for project automation. Browser modules and their Node tests use JavaScript to exercise actual browser logic. Keep additional runtimes out of the production site.
- Keep Ignite pinned with `Package.resolved`. Generate into staging before replacing output so stale pages disappear and generation failures preserve the previous successful tree.
- Never claim browser or screen-reader checks you did not perform. Automated checks do not establish real email-app handoff, offer redemption or assistive-technology behaviour.
- Keep local generation, deployment and launch readiness distinct. Verify hosting, HTTPS, actual approved offers and access instructions, email handoff and manual accessibility before announcing readiness.
