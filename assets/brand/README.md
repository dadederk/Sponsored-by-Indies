# Sponsored by Indies artwork

Ready-to-share artwork for conference websites, slides and printed materials.

| File | Use |
| --- | --- |
| `sponsored-by-indies-logo-full-colour-transparent.png` | Default logo: original blue and orange, on a transparent background. Use on white or light backgrounds. |
| `sponsored-by-indies-logo-black-transparent.png` | Entirely black logo on a transparent background, for light backgrounds or single-colour printing. |
| `sponsored-by-indies-social-preview.png` | 1200 × 630 sharing graphic. |
| `sponsored-by-indies-social-banner.png` | 1500 × 500 social banner. |
| `sponsored-by-indies-social-avatar.png` | 1024 × 1024 profile image. |

Both transparent logos are 4800 × 1400 pixels. They contain the original logo mark and “Sponsored by indies.” wordmark, without decorative background waves or a tagline. Keep their proportions and leave clear space around them. Avoid enlarging beyond their native resolution; at 300 pixels per inch, the full canvas is 16 × 4.67 inches.

The exports use the website's vector mark, shared wordmark layout and palette (`#245bc7` blue and `#b9470d` orange). The black export preserves the same transparency and antialiased edges.

To refresh these files from the repository root:

```sh
swift run --package-path Website --force-resolved-versions SponsoredByIndiesWebsite
cp Website/Build/sponsored-by-indies-logo-*-transparent.png assets/brand/
cp Website/Build/social-preview.png assets/brand/sponsored-by-indies-social-preview.png
cp Website/Build/social-banner.png assets/brand/sponsored-by-indies-social-banner.png
cp Website/Build/social-avatar.png assets/brand/sponsored-by-indies-social-avatar.png
```

The social graphics include their own backgrounds. For placing the logo in conference materials, choose one of the transparent PNGs.
