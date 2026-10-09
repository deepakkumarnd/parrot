# Customizing your site

Everything a reader sees comes from four places in your blog:
`views/layout.html.erb`, `css/`, `javascripts/app.js` and `images/`.

## The layout

`views/layout.html.erb` wraps every page; `<%= yield %>` is where the rendered
Markdown goes. Edit it to change your site name, tagline, nav and footer. The
nav links to Home, Categories and About by default.

## Set your site URL

Before deploying, set your site's URL in the layout's `og:url` and canonical
tags:

```html
<meta property="og:url" content="https://example.com">
<link rel="canonical" href="https://example.com">
```

Parrot rewrites both on each page, adding the built file's path
(`https://example.com/sample.html`, or `https://example.com/` for the index).
The sitemap, RSS feed and absolute `og:image` URLs also use this URL. Without
it, the sitemap and feed are skipped.

## SEO and link previews

The layout ships with Open Graph and Twitter card tags (`og:type`,
`og:site_name`, `og:image`, `twitter:card`), and Parrot fills in the page-specific
ones at build time:

- `<title>`, `og:title` and descriptions come from each post's
  [header](writing-posts.md#the-post-header).
- The index is `og:type=website`. Each post is `og:type=article` with an
  `article:published_time` from its `date`.
- A relative `og:image` path (such as `images/parrot.jpeg`) is copied into the
  build and rewritten to an absolute URL. For a local PNG, JPEG or GIF, Parrot
  also adds `og:image:width` and `og:image:height`. Swap in your own image, or
  use a full URL.
- Every page gets a schema.org JSON-LD block: `BlogPosting` for posts, `WebSite`
  for the index.
- Every page has exactly one `<h1>`.

## Light and dark theme

The site follows the reader's system light/dark setting, and the header has a
toggle button (`.theme-toggle`) to override it. The choice is saved in the
browser and applied by a small inline script in the layout before the page
first paints, so there's no flash of the wrong theme.

The toggle sets `data-theme="light"` or `data-theme="dark"` on `<html>`. The
colors are in `css/app.scss` and the toggle logic is in `javascripts/app.js`.
Remove the button from the layout to follow the system setting only.

## Styles and scripts

Every `.scss` and `.css` file under `css/` is concatenated and compiled to
`public/app.css`. `javascripts/app.js` is copied to `public/app.js` and loaded
with `defer`. The skeleton builds on [Simple.css](https://simplecss.org/).

The build adds these classes, so you can style them:

| Class | Element |
| --- | --- |
| `.post-meta` | The date and category line under a post's title |
| `.category-tag` | A link to a category page |
| `.back-link` | The link back to the index at the top of a post |
| `.post-tags`, `.tag` | The tag list at the bottom of a post |
| `.category-list` | The list on `categories.html` |

## Search

When search is on, the build adds the search box at the end of the `<header>`
on every page and loads `search.js` with `defer`. The box stays hidden
until the script has loaded. To put it somewhere else, add an empty
`<div class="search"></div>` where you want it in `views/layout.html.erb`. The
build fills that in, or removes it when search is off.

The box ships with a few default styles, all scoped under `.search` so a
theme's plain `input` or `li` rules don't leak in. They use Simple.css's color
variables when your theme defines them. These styles come before your own CSS
in `app.css`, so rules in `css/app.scss` with the same selectors (for example
`.search .search-input`) override them:

| Class | Element |
| --- | --- |
| `.search` | The container around the box and its suggestions |
| `.search-input` | The text box |
| `.search-suggestions` | The list of suggestions under the box |
| `.search-suggestion` | One suggestion, wrapping a link to the post |
| `.search-suggestion.is-active` | The suggestion picked with the arrow keys or mouse |
| `.search-empty` | The "No matching posts" line |

Readers can pick a suggestion with ↑/↓ and Enter or by clicking it, and press
Escape to clear the box. Turn search off with `search.enabled: false` in
[`config.yaml`](configuration.md#search).

## Syntax highlighting theme

Code blocks use Rouge's Monokai theme. It's set by `HIGHLIGHT_THEME` in the
gem's `lib/parrot/constants.rb` and accepts any Rouge theme name (`github`,
`gruvbox`, `molokai`, …). It isn't a `config.yaml` setting yet, so changing it
means editing a checkout of the gem.

## Icons

A parrot icon ships in three forms: `images/favicon.ico`, `images/favicon.svg`
and `images/apple-touch-icon.png`. Replace them with your own. Any `images/…`
file referenced from an `<img>` or `<link>` is copied into the build.

## The About and 404 pages

- `views/about.md` is built to `about.html` and linked from the nav. It takes the
  same `title`, `description` and `lang` header as a post, is listed in the
  sitemap, and stays out of the index and the feed. Delete the file and its nav
  link if you don't want an About page.
- `views/404.md` is built to `404.html`, marked `noindex` and kept out of the
  sitemap and feed.
