# Deployment

## Build and upload

```sh
parrot build
```

Upload the contents of `public/` to any static host: GitHub Pages, Netlify,
Cloudflare Pages, S3, nginx and so on. Leave out `public/.checksum`, which is
build state for `parrot serve`.

Before your first deploy, [set your site URL](customizing.md#set-your-site-url)
in the layout. The canonical URLs, sitemap and feed depend on it.

## Generated files

Besides one HTML page per post, the build writes:

| File | Contents |
| --- | --- |
| `index.html`, `index2.html`, … | The post listing. See [Pagination](configuration.md#pagination). |
| `categories.html`, `category-*.html` | Category pages. See [Categories](configuration.md#categories). |
| `about.html` | Built from `views/about.md`. |
| `404.html` | Built from `views/404.md`, marked `noindex`. |
| `sitemap.xml` | Every page. Posts have a `<lastmod>` from their `date`; the index uses the newest post's date. |
| `feed.xml` | An RSS 2.0 feed, newest post first, linked from every page for autodiscovery. |
| `robots.txt` | Points crawlers at the sitemap. |
| `search.js` | The search box's script and post index. Built only when `search.enabled` is `true`. See [Search](configuration.md#search). |
| `app.css`, `app.js`, `images/` | Compiled styles, scripts and the images pages use. |

If the layout has no `og:url` or canonical URL, the sitemap and feed are
skipped and `robots.txt` leaves out the `Sitemap:` line.

Most static hosts serve `404.html` for a missing path. `parrot serve` does the
same locally.

## How `parrot serve` rebuilds

- **On startup**, Parrot hashes every source file. If the result differs from
  `public/.checksum`, or that file is missing, it runs a full build and saves
  the new checksum. Otherwise it serves the existing `public/` straight away.
- **While running**, each saved file rebuilds only what it affects:
  - A post: that post, plus the index and category pages, `sitemap.xml` and
    `feed.xml`. The same goes for adding or removing a post.
  - `views/404.md` or `views/about.md`: that page.
  - Anything under `css/`, `javascripts/app.js` or an image: that asset.
  - `config.yaml`: the index, category pages, `sitemap.xml` and every post.
  - `views/layout.html.erb`: everything.

`public/.checksum` is gitignored in a new blog; don't deploy it.
