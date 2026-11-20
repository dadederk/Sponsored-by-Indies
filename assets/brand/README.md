# By Indies artwork

Ready-to-share artwork for conference websites, slides and printed materials. Files are grouped by site:

- `sponsored-by-indies/`: Sponsored by Indies logos, social images and README banner.
- `by-indies/`: By Indies social images and README banner.
- `../social/<conference>/<edition>/partners/`: approved conference partner posts.

Local cross and heart previews live in `Website/BuildArtwork/social/<conference>/<edition>/<partner>/` and are ignored by Git. Website builds use the same brand and conference folder names under each build root. Source SVGs, product artwork and portraits live in `Website/Assets/`.

The following files live in `sponsored-by-indies/`; By Indies social files use the `by-indies-` prefix in `by-indies/`.

| File | Use |
| --- | --- |
| `sponsored-by-indies-logo-full-colour-transparent.png` | Default logo: original blue and orange, on a transparent background. Use on white or light backgrounds. |
| `sponsored-by-indies-logo-black-transparent.png` | Entirely black logo on a transparent background, for light backgrounds or single-colour printing. |
| `sponsored-by-indies-social-preview.png` | 1200 × 630 sharing graphic. |
| `sponsored-by-indies-social-banner.png` | 1500 × 500 social banner. |
| `sponsored-by-indies-social-avatar.png` | 1024 × 1024 profile image. |
| `sponsored-by-indies-readme-banner.png` | 1800 × 450 repository banner. |

Both transparent logos are 4800 × 1400 pixels. They contain the original logo mark and “Sponsored by indies.” wordmark, without decorative background waves or a tagline. Keep their proportions and leave clear space around them. Avoid enlarging beyond their native resolution; at 300 pixels per inch, the full canvas is 16 × 4.67 inches.

The exports use the website's vector mark, shared wordmark layout and palette (`#245bc7` blue and `#b9470d` orange). The black export preserves the same transparency and antialiased edges.

To refresh these files from the repository root:

```sh
swift run --package-path Website --force-resolved-versions SponsoredByIndiesWebsite
swift run --package-path Website --force-resolved-versions SponsoredByIndiesWebsite --site showcase
mkdir -p assets/brand/sponsored-by-indies assets/brand/by-indies
cp Website/Build/assets/brand/sponsored-by-indies/*.png assets/brand/sponsored-by-indies/
cp Website/BuildIndies/assets/brand/by-indies/*.png assets/brand/by-indies/
```

The social graphics include their own backgrounds. For placing the logo in conference materials, choose one of the transparent PNGs.
