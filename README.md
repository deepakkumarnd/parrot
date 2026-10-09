<p align="center">
  <img src="skel/images/favicon.svg" alt="Parrot logo" width="96" height="96">
</p>

<h1 align="center">Parrot</h1>

<p align="center">
  <strong>A fast, minimal static site generator for Markdown blogs, written in Ruby.</strong>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/prt"><img src="https://img.shields.io/gem/v/prt?color=2f9e4d&label=gem" alt="Gem version"></a>
  <a href="https://github.com/deepakkumarnd/parrot/actions/workflows/ci.yml"><img src="https://github.com/deepakkumarnd/parrot/actions/workflows/ci.yml/badge.svg?branch=master" alt="CI status"></a>
  <img src="https://img.shields.io/badge/ruby-%3E%3D%203.2-CC342D" alt="Ruby 3.2+">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

<p align="center">
  <a href="docs/getting-started.md">Getting started</a> ·
  <a href="docs/README.md">Documentation</a> ·
  <a href="https://deepsnapster.com">Live demo</a> ·
  <a href="https://github.com/deepakkumarnd/parrot/issues">Report a bug</a>
</p>

---

Parrot turns a folder of Markdown files into a fast, SEO-ready blog of plain
HTML, CSS and JavaScript. There is no database, no JavaScript framework and no
build pipeline to configure: write posts in Markdown, run one command, and
upload the `public/` folder to any static host.

[deepsnapster.com](https://deepsnapster.com) is built with Parrot.

## Features

- **Markdown-first writing** — GitHub-flavoured Markdown via kramdown, with
  tables, footnotes, blockquotes and images.
- **Code and math out of the box** — syntax highlighting with Rouge and LaTeX
  rendered by MathJax.
- **Generated index** — the home page is built from your posts, newest first,
  with optional grouping by year or month and pagination.
- **Categories and tags** — a paginated page per category, a categories
  overview, and tags on every post.
- **SEO built in** — per-page titles, descriptions, canonical URLs, Open Graph
  and Twitter cards, schema.org JSON-LD, `sitemap.xml`, `robots.txt` and an RSS
  feed.
- **Instant search** — a search box that suggests posts by title, tag or
  category as you type, running entirely in the browser.
- **Light and dark theme** — follows the system setting, with a toggle that
  remembers the reader's choice.
- **Drafts** — preview unpublished posts locally; they never reach the build.
- **Live preview** — `parrot serve` rebuilds only what changed when you save a
  file.

## Quick start

Parrot needs Ruby 3.2 or newer.

```sh
gem install prt                      # installs the `parrot` command

parrot new blog                      # scaffold a new blog
cd blog
parrot post --title "Hello world"    # create a post
parrot serve                         # preview at http://localhost:8000
```

When you're ready to publish:

```sh
parrot build                         # writes the site to ./public
```

Then upload the contents of `public/` to GitHub Pages, Netlify, S3, nginx or
any other static host. See [Deployment](docs/deployment.md) for details.

> [!NOTE]
> The gem is published as **`prt`** because the name `parrot` on RubyGems
> belongs to an unrelated project. The command it installs is still `parrot`.

## Documentation

| Guide | What it covers |
| --- | --- |
| [Getting started](docs/getting-started.md) | Installation, commands and the layout of a blog |
| [Writing posts](docs/writing-posts.md) | Markdown features, the post header, drafts and placeholders |
| [Configuration](docs/configuration.md) | `config.yaml`: the index page, pagination and categories |
| [Customizing your site](docs/customizing.md) | Layout, site URL, SEO tags, light/dark theme and styles |
| [Deployment](docs/deployment.md) | Building, hosting, sitemap and feed, and how `serve` rebuilds |
| [Development](docs/development.md) | Working on Parrot itself, running tests and releasing |

## Contributing

Contributions are welcome — bug reports, documentation fixes and features
alike. Please read the [contributing guide](CONTRIBUTING.md) before opening a
pull request.

## License

Parrot is released under the [MIT License](LICENSE.txt).
