# Sponsored by Indies

![Sponsored by Indies. A little extra. From your community.](Images/readme-banner.png)

Free products and discounts from independent makers, included with tickets to iOS, Swift and Apple developer conferences. Contributions can include apps, games, tools, courses, books and more.

Visit [sponsored.byindies.com](https://sponsored.byindies.com). This repository contains the website’s code, content and artwork.

## Preview the website

The site uses [Ignite](https://github.com/Ignite-Swift/Ignite), a tool that turns code written in the Swift programming language into website pages.

You’ll need a Mac with Xcode 26.3 or later, which includes Swift, and Python 3 for the preview server. Install the [Ignite command-line tool](https://github.com/Ignite-Swift/Ignite/tree/0.7.2#getting-started), then run these commands in Terminal:

```sh
git clone https://github.com/dadederk/Sponsored-by-Indies.git
cd Sponsored-by-Indies/Website
ignite build
ignite run --preview
```

The first Ignite command creates the pages; the second opens them in your browser. Press Return in Terminal to stop the preview. After editing, run `ignite build` in another Terminal window and reload the page.

## Make changes

| Folder | What you’ll find |
| --- | --- |
| `Website/Data/` | Conference, maker and offer details |
| `Website/Sources/SponsoredByIndiesWebsite/` | Code for the pages, shared elements and website generation |
| `Website/Assets/` | Styles, logos and code that runs in the browser |
| `Website/Tests/` | Automated checks |

Keep existing page addresses and add only approved conference and offer details. Each year’s participation and offers need fresh approval.

Read [AGENTS.md](AGENTS.md) for coding conventions and verification guidance.

Bundle cards appear in descending order of potential saving, using US prices in USD as the shared baseline. Each price record identifies the exact store plan, regular price, discount percentage, eligible period, source, observed prices and check date. Savings use decimal arithmetic and round down to cents; both ranking and bundle totals use that same calculation. Alternative offers for one product are not added together. Equal savings use app name, maker ID and product URL for stable ordering.

Bundle totals are generated from the explicitly reviewed compatible offer IDs. Validation rejects duplicate products, missing evidence, a lower-value alternative, invalid percentages, mismatched currency or storefront, and fractional-cent reference prices. The headline rounds the computed total down to whole dollars and shows it as potential value. Each card’s terms show the exact reference price, plan and source. Keep internal price-review notes and contributor follow-ups in private planning; the repository check rejects price-review note fields in conference data. Check dates appear in the bundle’s calculation details. Final checkout prices and eligibility can differ.

For current and upcoming editions, builds reject future-dated evidence and prices checked more than 30 days ago. Historical editions retain their original evidence. Routine builds stay offline. To check the public sources explicitly, run:

```sh
swift run --package-path Website --force-resolved-versions SponsoredByIndiesWebsite --verify-prices
```

This read-only command checks approved offers for current and upcoming editions, leaving archived evidence intact. It compares exact App Store plan labels, or an exact product name in Schema.org JSON-LD offers, and all distinct matching USD prices against the recorded observations. For structured sources, set `sourceFormat` to `schemaOrg` and record `sourceProductName`; App Store sources are the default. Structured checks read the named product’s USD offer, not unrelated promotional text or team prices. Use the regular price applicable to the conference period, rather than an introductory offer that ends before it. Missing or changed prices fail the check; it never picks the first or largest price, changes content, or refreshes dates automatically. Multiple prices under one plan name require an explicitly marked provisional selection. Record the reasoning and any maker-confirmation task in private planning, outside the website repository. Matching a public listing does not confirm which price a particular customer or offer is eligible for; confirm ambiguous plans with the maker. After reviewing a successful check, update the evidence and check date together. Use `--verify-prices` and `--validate-only` separately; validation stays offline.

The repository maintainer reviews scheduled price-check failures, confirms ambiguous plans with the maker, and updates the evidence and check date together. Run this offline check for seven days of notice before evidence expires:

```sh
swift run --package-path Website --force-resolved-versions SponsoredByIndiesWebsite --check-maintenance
```

The maintenance check reports provisional selections without treating them as confirmed. Neither it nor the live check updates dates or content. Keep current evidence under review at least every three weeks; archived editions keep their original evidence.

## Build and check

For the full checks, also install [Node.js 22.12 or later](https://nodejs.org/) to test the code that runs in visitors’ browsers.

Run the following from the main project folder. If you’re still in `Website`, run `cd ..` first:

```sh
swift Scripts/CheckPublicRepository.swift
swift test --package-path Website --force-resolved-versions

swift run --package-path Website --force-resolved-versions SponsoredByIndiesWebsite
swift run --package-path Website --force-resolved-versions SponsoredByIndiesWebsite \
  --public --site-url https://sponsored.byindies.com

PUBLIC_SITE_URL=https://sponsored.byindies.com node --test Website/Tests/*.test.mjs

cd Website
npm ci --ignore-scripts
npx playwright install chromium webkit
npm run test:browser
```

These commands check the content, run tests and create both the preview and public pages. Both builds are needed for the final checks. The Swift commands let us include the website’s address when creating the public pages.

Browser checks use Chromium and WebKit at desktop and narrow mobile widths. They cover navigation, dialog focus, form validation, repeatable contributions, email-file attachments, script-failure fallbacks and automated accessibility checks. The browser packages are development dependencies; they add nothing to the published site. Failures produce a local HTML report in `Website/playwright-report`, also saved by GitHub for seven days.

Generated pages go into `Website/Build` and `Website/BuildPublic`. GitHub runs these checks automatically and publishes the website when changes reach `main`, the project’s main branch. It also rebuilds daily at 05:37 UTC to refresh date-dependent pages, and checks live prices and approaching evidence expiry independently. Failed publication leaves the last deployed website intact. Check scheduled runs in GitHub Actions; scheduling can be delayed, and GitHub may disable schedules in inactive repositories.

Before releasing a changed interaction, also check VoiceOver in Safari, keyboard navigation, zoom and larger text. Open both a text-only draft and an image-bearing `.eml` file in the supported email apps, check the recipient, text and attachments, and discard the drafts. Automated checks do not verify screen-reader announcements or email-app behaviour.

## Get involved

[Report a problem or suggest an improvement](https://github.com/dadederk/Sponsored-by-Indies/issues). Changes to the code are welcome too.

To contribute a product or discuss a conference, use the website’s [participation pages](https://sponsored.byindies.com/participate/).

## Credits

Coordinated by [Dani Devesa Derksen-Staats](https://github.com/dadederk), who also writes [Accessibility up to 11](https://accessibilityupto11.com).

Built with [Ignite](https://github.com/Ignite-Swift/Ignite), created by [Paul Hudson](https://github.com/twostraws) and developed with the Ignite community. This project uses version 0.7.2, available under the [MIT license](https://github.com/Ignite-Swift/Ignite/blob/0.7.2/LICENSE).

Thanks to the independent makers, conference organisers and accessibility community for their contributions and feedback.
