# Landing page

Static site built from the design canvas ("Landing page" page: desktop 1440, mobile 360, consent bar, share image).
No build step: upload this folder to any static host (GitHub Pages, Netlify, Cloudflare Pages).

| File | What |
|---|---|
| `index.html` | Landing page (responsive 360 px → desktop), cookie bar, PostHog after consent |
| `privacy.html` | Privacy policy, **draft**: legal review for LGPD before launch |
| `delete-account.html` | Account deletion page (Google Play requires this link) |
| `og-image.png` / `.svg` | 1200×630 social share image (SVG is the source) |

## Before going live
In the `SITE` block at the bottom of `index.html` (and the short one in the two other pages):
- `appName`, `contact`: real app name and contact email
- `playUrl`: Google Play listing; `preRegister: false` once the app is live
- `posthogKey`: turns on analytics and the cookie bar
- `og:image` needs an absolute URL for social previews: change `og-image.png` to `https://<your-domain>/og-image.png`

Regenerate the share image after a name change: edit `[App name]` in `og-image.svg`, then
`python3 -c "import cairosvg; cairosvg.svg2png(url='og-image.svg', write_to='og-image.png')"` (needs the brand fonts installed).
