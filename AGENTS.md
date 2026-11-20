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
- After changing the logo, palette or artwork renderer, rebuild both sites and refresh `assets/brand/<site>/` using the commands in `assets/brand/README.md`. The source README uses the Sponsored banner from that folder.
- Keep generated artwork paths in `ArtworkPaths.swift`. Group brand exports by site and social exports by conference and edition; use descriptive lowercase filenames with hyphens. Keep only standard browser-discovery icons at the site root. Local partner previews belong in the ignored `Website/BuildArtwork/` tree.
- Use lowercase folder names with hyphens for asset categories and stable site, conference, edition and partner slugs. Reuse `assets/brand/<site>/` and `assets/social/<conference>/<edition>/` beneath each output root; use `partners/` and `constellations/` consistently. Local previews mirror that hierarchy, adding a partner folder for its variants. Keep existing Swift source folders and build-root names unchanged.

## Card content

- Lead with the product: one card per product, linked icon and name, grouped alternative offers. Keep builder details and quotes smaller and secondary.
- Prefer original App Store artwork for listed apps, using the square 512-pixel or larger asset rather than padded or pre-rounded store thumbnails. If Mac artwork includes extra canvas padding, prefer the maker’s unpadded press asset at the standard display size. Use the maker’s press kit or website for other products; keep a local copy.
- Align section starts within each row; support narrow screens and enlarged text. Give compact conference-bundle links their own divider.
- Align bundle maker credits within each row, independently of quote length or absence. Keep quotes above the credits and let single-column cards follow their natural content height.
- Write two short third-person bio sentences about the person’s role or approach, using their website and supplied facts. Cut filler and redundant mentions of the featured product.
- Keep full names in builder profiles; use `creditName` for short bundle credits. Link collaborators individually and match the order of names and conference roles.
- Keep builder profiles to five links at most, including Website. Choose the most relevant verified profiles rather than filling every social slot.
- Try X portraits first, then the maker’s website or another verified profile. Store images locally, retain the social link, and use initials if needed. Never guess profile URLs.
- Fit generated square app icons to their near-opaque tile bounds so Mac-icon shadows do not make them appear smaller. For non-square covers, trim only fully transparent outer canvas and preserve proportions and visible pixels. Retain source masters and portrait framing; avoid per-project CSS scale adjustments.
- Give profile photos a thin, subtle border so pale backgrounds remain distinct from the card.
- Keep quotes brief and faithful. Omit attribution for a sole maker; use plain “– Name” for shared products. Leave quote credits unlinked; retain source URLs in the data.
- Treat supplied maker copy and confirmed offer prices as the source of truth. Record confirmed prices explicitly; keep the supporting correspondence private.
- Terms use one bullet per option: estimated payment, saving, linked regular US price and exact plan. Say “Choose one offer” once for alternatives; share identical redemption instructions once. Subscriptions return to the regular price at renewal unless an exception is specified.
- Use US/USD references and the same conservative calculation for ranking and totals. Count only the largest compatible saving per product; round the headline down to whole dollars. Follow the README’s evidence and rounding rules.
- Keep check dates in the collapsed value calculation. Keep internal approval discussions and provisional price-review notes in private planning.
- When a contribution is approved, generate and visually check its partner artwork, then refresh that edition’s `assets/social` export using the README commands and configured groups. Keep draft artwork private.
- Promotional artwork has three kinds: conference × Sponsored by Indies, conference × each approved project or deliberate related-project group, and constellations as the existing layout fills, with a final partial batch near the conference. Group related products from the same maker explicitly in edition data; do not automatically group everything a maker contributes.
- Keep promotional generation deterministic: fixed geometry, ordered project IDs, stable descriptive filenames and an export index without timestamps.
- Keep constellations visually close to the approved reference: projects around the conference logo, with larger imagery for projects providing larger discounts. Record explicit positions and sizes per batch so later discount changes do not alter an already published graphic. Agree the discount metric and sizing rule before automating the renderer.
- Track constellation membership and pending products in private planning. Build the next constellation from newly approved products once they fill the existing layout. Near the conference, publish a partial final batch to give visibility to projects not included in previous rounds; do not wait for every slot to fill. Preserve earlier batches and record each batch’s asset, capacity, ordered product IDs, positions and sizes. Record actual publication separately from generation.

## Public copy

- Write for iOS, Swift and Apple-platform conference communities. Avoid “pilot”, “we’re starting with” and speculative expansion plans in visitor copy.
- Make the ticket relationship explicit: free products and discounts are included with the named conference’s ticket. Distinguish free access from a discount.
- Keep outreach, draft examples and internal assumptions in private planning. Mention uncertainty only when visitors need it, such as redemption dates, eligibility or renewal terms. Confirmation of an offer does not mean redemption is open.
- Separate what attendees, organisers and indies get. Keep conference benefits distinct from what we ask in return. Describe indie visibility as an opportunity, without promising downloads or sales.
- Prefer one clear heading per section; remove repeated eyebrow text and duplicate invitations. Reuse audience cards and copy across pages, choosing the audiences and order appropriate to each page.
- Name link destinations accurately: a conference bundle, the conference’s own website, or an in-page section. Keep the main call to action distinct from section navigation.
- Use “Terms” for offer details and the discreet permalink control for sharing. Value breakdowns use one bullet per product, with its calculation and a short inline price-reference link.
- Use warm, concrete language that includes solo makers and small teams. Conference quotes are optional. Keep conference-specific jokes, sign-offs and identity in conference data. Avoid all-caps prose while respecting official names such as ARCtic.

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
