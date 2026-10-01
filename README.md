# Parrot

A static site generator for Markdown blogs, written in Ruby. Point it at a
folder of Markdown and it produces a folder of HTML/CSS/JS. Syntax highlighting
and LaTeX math work out of the box.

Demo: [deepsnapster.com](https://deepsnapster.com) is built with Parrot.

## Installation

Parrot needs Ruby 3.2 or newer (developed and tested on 4.0). It is
published on RubyGems as `prt`:

```
$ gem install prt
```

That puts the `parrot` command on your `PATH`. Or add it to a `Gemfile`:

```ruby
gem 'prt'
```

then run `bundle install` and use `bundle exec parrot`.

## Quick start

```
$ parrot new blog                     # scaffold a blog from the skeleton
$ cd blog
$ parrot post --title "Hello world"   # add a post — it appears in the generated index automatically
$ parrot serve                        # build, then serve on http://localhost:8000 and rebuild on change
```

For a one-off build without the server:

```
$ parrot build        # writes the site into ./public
```

## Commands

| Command            | What it does                                                    |
| ------------------ | -------------------------------------------------------------- |
| `parrot new <dir>`      | Copy the skeleton blog into `<dir>` (must not already exist)              |
| `parrot post --title "<title>"` | Scaffold `views/posts/<slug>.md` with today's date                |
| `parrot build`          | Build the current blog into `public/`                                    |
| `parrot serve`          | Build, serve `public/` on port 8000, and watch for changes               |

Global flags: `-q` / `--quiet`, `-v` / `--version`, `-h` / `--help`.

`post`, `build` and `serve` operate on the current working directory, so run
them from the blog's root.

## Project layout

A generated blog looks like this:

```
blog/
├── config.yaml            # post listing settings — see "The index page" below
├── views/
│   ├── layout.html.erb   # page wrapper; <%= yield %> is the rendered Markdown
│   ├── 404.md            # built to public/404.html
│   ├── about.md          # built to public/about.html, linked from the nav
│   └── posts/
│       └── *.md          # one Markdown file per post
├── css/
│   └── **/*.{scss,css}   # concatenated and compiled to public/app.css
├── javascripts/
│   └── app.js            # copied to public/app.js
├── images/               # images referenced from pages are copied to public/images/
└── public/               # build output — serve/deploy this, don't edit it
```

There's no `views/index.md` — the home page is generated at build time from
everything in `views/posts/*.md`.

## Writing posts

Parrot uses simple markdown format https://www.markdownguide.org/basic-syntax/ for
text formatting.

Posts are [kramdown](https://kramdown.gettalong.org/) Markdown with GitHub-style
fenced code blocks. A fresh blog ships `views/posts/about_parrot.md` (headings,
code, math) and `views/posts/sample.md` (images, lists, tables, quotes) as
worked examples of everything below.

- **Headings** — `#` for the post title, `##` / `###` for sections.
- **Code** — inline with `` `backticks` ``; fenced blocks tagged with a language
  are syntax highlighted with [Rouge](https://github.com/rouge-ruby/rouge):

  ````
  ```ruby
  puts "hello"
  ```
  ````

  The theme is Monokai. It's set by `HIGHLIGHT_THEME` in the gem's
  `lib/parrot/constants.rb` (any Rouge theme name: `github`, `gruvbox`,
  `molokai`, …), so changing it means editing the installed gem or a checkout
  of it — it isn't a `config.yaml` setting yet.
- **Math** — LaTeX between `$$ … $$` is rendered by MathJax: inline when it sits
  inside a line, a display block when it's on its own line.
- **Tables** — GitHub-style pipe tables render to HTML:

  ```
  | Feature | Supported |
  | ------- | --------- |
  | Tables  | yes       |
  ```
- **Blockquotes** — a line starting with `>`:

  ```
  > Blockquotes are good for asides and pull quotes.
  ```
- **Internal links** — `[text](#sample.md)` is rewritten to `sample.html` during
  the build, so link posts to each other by their Markdown filename.
- **`{post_title}`** — a literal `{post_title}` anywhere in a post's body is
  replaced with its header `title`. `parrot post` starts every post with
  `# {post_title}`, so the heading follows the header.
- **`{post_date}`** — a literal `{post_date}` placeholder anywhere in a post's
  body is replaced at build time with its header `date`, formatted per
  `post_date_format.on_post` in `config.yaml` (see "The index page" below).

Right under each post's `<h1>`, the build adds a
`<p class="post-meta">` line with the post's date (per
`post_date_format.on_post`) and its category as a
`<a class="category-tag">` link to that category's page. Either part is
left out when the header doesn't have it. Posts written by older versions of
`parrot post` have a `_{post_date}_` line under the title; it's replaced by
this line, so the date isn't shown twice.

Every built post also gets a link back to the index (`<p class="back-link">`) at
the top of its `<main>`, pointing at the index page that lists it
(`index.html`, or `index2.html`, … once the index is paginated); style it with the
`.back-link` class in your CSS. The index page doesn't get one. Its text is
`config.yaml`'s `post_listing.back_link_text` (default "← Back to all posts";
"" omits the link — see "The index page" below).

## Post header

Each post starts with an HTML comment holding its metadata. `parrot post` writes
`title`, `date`, `lang` and an empty `category`; `description` and `tags` are
ones you can add by hand:

```
<!--
title: My new post title
date: 08/09/2026
lang: en
category: Programming
description: One or two sentences for search results and social cards.
tags: algorithms, coding
-->
```

`title` becomes the page's `<title>` and `og:title` at build time. `lang` sets
`<html lang="…">` for that page — leave it `en`, or set it per post (`ml`, `hi`,
…) when a post is in another language, which also feeds `og:locale`.
`description` is optional: it fills `<meta name="description">`, `og:description`
and `twitter:description`, and Parrot falls back to the post's first paragraph
when it's absent. `tags` is an optional comma-separated list: when present,
the tags are listed at the bottom of the post as
`<p class="post-tags">Tags: <span class="tag">algorithms</span> …</p>` (style it
with `.post-tags` / `.tag`), and emitted as `article:tag` meta tags and the
JSON-LD `keywords`. `{post_tags}` in `list_format` shows them on the index as
written. `category` is optional and takes one name per post; see "Categories"
below. Set your site's URL once in `views/layout.html.erb` — the
`<meta property="og:url">` and `<link rel="canonical">` tags — and Parrot
rewrites both per page, appending the built file's path
(`https://example.com/post1.html`, `https://example.com/` for the index).

The layout also ships link-preview tags — `og:type`, `og:site_name`, `og:image`
and `twitter:card`. A relative `og:image` path (`images/parrot.jpeg`) is copied
into the build and rewritten to an absolute URL; swap it for your own image or a
full URL. When it's a local PNG/JPEG/GIF, Parrot reads its size and adds
`og:image:width`/`height`. The index stays `og:type=website`; each post is built
as `og:type=article` with an `article:published_time` derived from its header
`date`. Every page also gets a schema.org JSON-LD block — `BlogPosting` for
posts, `WebSite` for the index.

Other layout defaults worth knowing: `app.js` loads with `defer`, the CDNs are
`preconnect`ed, `theme-color` is set for light and dark, and a parrot icon ships
in three forms — `images/favicon.ico`, `images/favicon.svg` and
`images/apple-touch-icon.png` (swap in your own). Any `images/…` file referenced
from an `<img>` or `<link>` is copied into the build.

## Light and dark theme

The skeleton follows the visitor's system light/dark setting, and the header has
a toggle button (`.theme-toggle`) to override it. The choice is saved in
`localStorage` and applied by a small inline script in `views/layout.html.erb`
before first paint, so there's no flash of the wrong theme. The toggle sets
`data-theme="light"` or `"dark"` on `<html>`; the matching colors are in
`css/app.scss` and the toggle logic is in `javascripts/app.js`. Remove the
button from the layout if you only want the system setting.

## Draft mode

```
<!--
title: My new post title
date: 08/09/2026
lang: en
description: One or two sentences for search results and social cards.
draft: true
-->
```

Add `draft: true` to a post's header to keep it unpublished (posts aren't
drafts by default). `parrot build` skips drafts entirely — no page, and nothing
in the index listing, `sitemap.xml` or `feed.xml`. `parrot serve` builds and
lists them so you can preview them.

## The index page

`public/index.html` is generated at build time from every file in
`views/posts/*.md`, newest first — there's nothing to hand-edit. How it's
rendered is controlled by `config.yaml` at the blog's root:

```yaml
post_listing:
  list_title: "Post listing"                         # heading above the listing (page 1 only); "" omits it
  back_link_text: "← Back to all posts"               # the link atop every post; "" omits it
  group_by: none                                      # none | year | month
  # per_page: 10                                      # posts per index page; unset or 0 = one page
  newer_link_text: "← Newer posts"                    # pager links; "" omits that link
  older_link_text: "Older posts →"
  list_format: "{post_date} ~ [{post_title}]({post_link}) {post_category_tag}"

post_date_format:
  on_list: "%m/%Y"     # {post_date} inside list_format above
  on_post: "%d/%m/%Y"  # a literal {post_date} placeholder inside a post's own body
```

**`group_by`** wraps the listing in `## <year>` or `## <Month Year>` sections
(newest first); `none` is a flat list.

**`per_page`** splits the listing once there are more posts than that:
`index.html` holds the newest posts, then `index2.html`, `index3.html`, and so
on, each with a pager at the bottom using `newer_link_text` / `older_link_text`.
Every index page is listed in `sitemap.xml`, and a stale trailing page is
removed when the post count drops.

**`list_format`** is a Markdown template applied to each post:

- `{post_<key>}` — that key from the post's header, as plain text:
  `{post_title}`, `{post_lang}`, or any custom field you add to a post's
  `<!-- key: value -->` header.
- `{post_date}` — the header's `date`, formatted per `post_date_format.on_list`
  rather than shown as-authored.
- `{post_category_tag}` — the post's `category` as a `<a class="category-tag">`
  link to its category page; empty for a post without one. Leave it out of
  `list_format` to hide categories in listings.
- `{post_link}` — the post's href, the one field Parrot computes itself rather
  than reading from the header. Wrap whichever part should be clickable in
  Markdown link syntax yourself: `[{post_title}]({post_link})` links just the
  title; `[{post_date} ~ {post_title}]({post_link})` links the whole line.
- Anything else in `{…}` is a Ruby [`strftime`](https://ruby-doc.org/3.2.2/Date.html#method-i-strftime)
  format string applied to the post's header `date` directly, e.g.
  `{%A, %B %d %Y}` — shown as formatted, not run through `post_date_format`.

`post_date_format.on_list` and `.on_post` are themselves `strftime` format
strings, formatting `{post_date}` wherever it's used — in `list_format` above,
and as a literal `{post_date}` placeholder inside a post's own Markdown body
(see "Writing posts").

`config.yaml` is optional; a missing file, section, or key falls back to the
defaults shown above.

## Categories

Give a post one category in its header (`category: Ruby`) and the build adds:

- **`category-ruby.html`**, listing that category's posts newest first. It uses
  the same `list_format`, `group_by` and pager as the index. Once a category
  has more posts than `per_page`, the listing continues on
  `category-ruby_2.html`, `category-ruby_3.html`, and so on.
- **`categories.html`**, linked from the layout's nav, listing every category
  with its post count (`<ul class="category-list">`).
- A link to the category under the post's title, and in listings through
  `{post_category_tag}`.

Page names come from the category's name, lowercased, with spaces as hyphens and
anything other than letters, digits and hyphens dropped. Names that end up the
same ("C++" and "C") share one page, and the build warns about it. A post can't
be named `category`, `categories`, or after a category page that the build
writes (`category-ruby.md`). Category pages are listed in `sitemap.xml`.

## How `serve` rebuilds

- On startup Parrot hashes every source file. If the combined checksum differs
  from `public/.checksum` — or that file is missing — it runs a full build and
  then writes the new checksum. Otherwise it skips straight to serving the
  existing `public/`.
- While running, each saved file rebuilds only what it affects: a single post,
  a new/removed post, `views/404.md`, `views/about.md`, the compiled CSS, `app.js`, or a copied
  image. Because the index is generated from `views/posts/*.md`, adding,
  removing or editing a post also rebuilds the index and category pages (along
  with `sitemap.xml` and `feed.xml`); editing `config.yaml` rebuilds the index,
  category pages, `sitemap.xml` and every post, since it can affect both the listing and each post's
  `{post_date}` placeholder. Editing `views/layout.html.erb` rebuilds
  everything.
- `public/.checksum` is regenerated build state. It is gitignored and must not
  be deployed.

## Deployment

Run `parrot build` and upload the contents of `public/` to any static host —
GitHub Pages, Netlify, S3, nginx, and so on. Exclude `public/.checksum`.

The build also writes `public/sitemap.xml` (every post with a `<lastmod>` from
its `date`, and the index dated to the newest post), `public/robots.txt`
pointing crawlers at it, and `public/feed.xml` (an RSS 2.0 feed, newest post
first, linked from every page for autodiscovery). These use the base URL from
`views/layout.html.erb`, so set that before deploying; if the layout has no
`og:url`/canonical, the sitemap and feed are skipped and `robots.txt` omits the
`Sitemap:` line.

`views/404.md` is built to `public/404.html` (marked `noindex`, kept out of the
sitemap and feed) for hosts that serve it on a missing path. `parrot serve` does
the same locally, answering a missing path with that page and a 404 status.

`views/about.md` is built to `public/about.html`, which the layout's nav links
to from every page — put your bio and social links there. It takes the same
optional `title`/`description`/`lang` header as a post, is listed in the
sitemap, and stays out of the index listing and the feed. Delete the file (and
its nav link) if you don't want an About page.

`about`, `404`, `index`, `index2`, `index3`, …, `categories`, `category`, `now`,
`post`, `posts`, `note` and `notes` are reserved post names — the first few would overwrite Parrot's
own pages, the rest are kept free for pages of their own. `parrot post` refuses
such a title, and `parrot build` fails if one is in `views/posts/`.

## Development

```
$ ./bin/setup                 # install gems and the git hooks
$ bundle exec rspec           # run the test suite
$ bundle exec rspec -f d      # documentation format
$ bundle exec rubocop         # lint (config in .rubocop.yml)
$ bundle exec rubocop -a      # autocorrect safe offenses
```

`bin/setup` runs `bundle install` and then points git at the versioned hooks
in `.githooks/` (`git config core.hooksPath .githooks`). Run it once after
cloning. From then on the `pre-commit` hook runs RuboCop and RSpec, and aborts
the commit if either fails.

Run the suite from a directory that has no `blog/` folder — some specs create
and delete `./blog`.

GitHub Actions (`.github/workflows/ci.yml`) runs RSpec and RuboCop on every pull
request and on pushes to `master`.

## Releasing

The gem is published on RubyGems as `prt` (the name `parrot` belongs to an
unrelated gem). Releases use Bundler's gem tasks:

1. Bump the version and commit. `bundle exec rake bump_patch_version` bumps the
   patch number (0.3.0 → 0.3.1) in `lib/parrot/metadata.rb` and
   `spec/parrot/metadata_spec.rb` and runs that spec; for a minor or major
   bump, edit both files by hand.
2. Run `bundle exec rake release`. It refuses to run with uncommitted changes.
   It builds `pkg/prt-<version>.gem`, tags `v<version>`, pushes `master` and the
   tag, and pushes the gem to RubyGems. You need to be signed in (`gem signin`)
   and will be asked for your MFA code.

`bundle exec rake build` builds the gem without publishing it, and
`bundle exec rake install` installs it locally.

## Contributing

1. Fork it
2. Create a branch named after its GitHub issue: `feat/<issue>-<short-name>`
   for features, `fix/<issue>-<short-name>` for bugs (e.g. `feat/2-post-tags`)
3. Commit your changes
4. Push the branch and open a Pull Request

## License

MIT — see [LICENSE.txt](LICENSE.txt).
