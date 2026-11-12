# Sponsored by Indies conventions

Read [README.md](README.md) for project structure, local preview and verification commands. This is a Swift static site built with Ignite. Keep contributor documentation focused on building, changing and testing this public website, using concise, plain English.

## Prefer Ignite

- Start with Ignite's components, layout containers, themes and SwiftUI-like modifiers. Prefer those APIs for spacing, sizing, alignment, colours, typography and control appearance before adding classes, inline styles or custom CSS.
- Ignite resembles SwiftUI but is a separate framework. Check the pinned source in `Website/.build/checkouts/Ignite` for supported APIs and their generated markup; do not assume a SwiftUI modifier exists or behaves the same way.
- Compose pages from Ignite elements rather than assembling HTML strings. Use `Tag` for native elements or attributes Ignite cannot express, preserving browser behaviour.
- Use Ignite's theme and role APIs for shared presentation. Use Bootstrap classes only when Ignite has no suitable modifier, and keep the reason clear.
- Add custom CSS only for a requirement the framework cannot express cleanly, such as shared fluid layouts, inherited conference variables or descendant/state selectors. Keep justified shared rules rather than replacing them with repeated per-element styles.
- Limit JavaScript to browser behaviour Ignite cannot provide. Keep it in small modules with static content and direct email fallbacks. Use the native `hidden` attribute when toggling `element.hidden`; Ignite's `.hidden()` generates a class instead.

## Structure and shared design

- Keep pages focused on composition, shared UI in `Components`, content models and validation in `Models`, and generation concerns in `Publishing`.
- Use descriptive names, small functions and explicit dependencies. Extract repeated behaviour with a clear purpose; avoid speculative abstractions.
- Keep `AnyHTML` at necessary heterogeneous boundaries, such as the page registry. Preserve concrete types elsewhere where practical.
- Write comments for decisions and invariants rather than restating the code.
- Define site colours, spacing and dimensions in `DesignTokens.swift`. Components and CSS consume those definitions instead of duplicating values.
- Bind brand SVG paints to palette variables with preview fallbacks, resolving them during generation. Keep conference palettes in their conference JSON records.
- After changing the logo, palette or artwork renderer, rebuild and copy `Website/Build/readme-banner.png` to `Images/readme-banner.png` to refresh the README banner.

## Content and generation

- Load editorial content from `Website/Data`. Commit only approved content; filtering generated output does not hide source records in a public repository. Keep credentials and redemption codes out of source and generated assets.
- Keep conference identity, editions, participation and offers in separate per-conference records. Share maker identities through `indies.json`.
- Keep IDs and routes stable when labels change. Adding a conference or edition should require data changes only; keep its branding and prose out of shared Swift and CSS.
- Validate participation and offer approval separately for each edition. Approval and discounts do not carry across years; an approved offer requires approved participation in the same edition.
- Load and validate all content before resolving references or rendering. Fail on invalid content rather than generating incomplete pages. Escape editorial text and attributes at the Ignite rendering boundary, and encode URL components appropriately.
- Keep typed relational data in JSON. If substantial editorial Markdown is needed, use Ignite's supported content pipeline rather than a custom front-matter parser.
- Generate into staging before replacing output so stale pages disappear and failures preserve the previous successful tree. Generated builds are disposable and excluded from source control.

## Verification

- After a coherent change, run the Swift tests, preview and public generation, Node checks and repository check listed in the README.
- Add meaningful regression tests for changed behaviour, including validation, approval, dates, links and browser interactions. Use Swift Testing for Swift tests and Node tests for browser modules. Avoid tests that merely reproduce styling or implementation details.
- Prefer Swift for project automation and keep additional runtimes out of the production site.
- Keep Ignite pinned through `Package.swift` and `Package.resolved`; use `--force-resolved-versions` for reproducible checks.
- Run `swift Scripts/CheckPublicRepository.swift` before committing. Keep its file allowlist aligned with the intended website sources, assets, tests and contributor documentation.
- Report checks actually performed and distinguish local generation from deployment. Verify generated links, metadata and the real email-app handoff when those behaviours change.
