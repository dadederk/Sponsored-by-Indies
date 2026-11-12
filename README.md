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

## Build and check

For the full checks, also install [Node.js 22 or later](https://nodejs.org/) to test the code that runs in visitors’ browsers.

Run the following from the main project folder. If you’re still in `Website`, run `cd ..` first:

```sh
swift Scripts/CheckPublicRepository.swift
swift test --package-path Website --force-resolved-versions

swift run --package-path Website --force-resolved-versions SponsoredByIndiesWebsite
swift run --package-path Website --force-resolved-versions SponsoredByIndiesWebsite \
  --public --site-url https://sponsored.byindies.com

PUBLIC_SITE_URL=https://sponsored.byindies.com node --test Website/Tests/*.test.mjs
```

These commands check the content, run tests and create both the preview and public pages. Both builds are needed for the final checks. The Swift commands let us include the website’s address when creating the public pages.

Generated pages go into `Website/Build` and `Website/BuildPublic`. GitHub runs these checks automatically and publishes the website when changes reach `main`, the project’s main branch.

## Get involved

[Report a problem or suggest an improvement](https://github.com/dadederk/Sponsored-by-Indies/issues). Changes to the code are welcome too.

To contribute a product or discuss a conference, use the website’s [participation pages](https://sponsored.byindies.com/participate/).

## Credits

Coordinated by [Dani Devesa Derksen-Staats](https://github.com/dadederk), who also writes [Accessibility up to 11](https://accessibilityupto11.com).

Built with [Ignite](https://github.com/Ignite-Swift/Ignite), created by [Paul Hudson](https://github.com/twostraws) and developed with the Ignite community. This project uses version 0.7.2, available under the [MIT license](https://github.com/Ignite-Swift/Ignite/blob/0.7.2/LICENSE).

Thanks to the independent makers, conference organisers and accessibility community for their contributions and feedback.
