# Parrot

A small static site generator for Markdown blogs, written in Ruby. Point it at a
folder of Markdown and it produces a folder of HTML/CSS/JS. Syntax highlighting
and LaTeX math work out of the box.

Demo: [deepsnapster.com](https://deepsnapster.com) is built with Parrot.

## Installation

Parrot needs Ruby (developed and tested on 4.0; 3.x should work). Add it to a
`Gemfile`:

```ruby
gem 'parrot', git: 'git@github.com:deepakkumarnd/parrot.git'
```

then:

```
$ bundle install
```

Run it as `bundle exec parrot`, or `gem install` the built gem to get a bare
`parrot` on your `PATH`.

## Quick start

```
$ parrot new blog                     # scaffold a blog from the skeleton
$ cd blog
$ parrot post --title "Hello world"   # add a post and link it from the index page
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
| `parrot post --title "<title>"` | Scaffold `views/posts/<slug>.md` and link it from `index.md` with today's date |
| `parrot build`          | Build the current blog into `public/`                                    |
| `parrot serve`          | Build, serve `public/` on port 8000, and watch for changes               |

Global flags: `-q` / `--quiet`, `-v` / `--version`, `-h` / `--help`.

`post`, `build` and `serve` operate on the current working directory, so run
them from the blog's root.

## Project layout

A generated blog looks like this:

```
blog/
├── views/
│   ├── layout.html.erb   # page wrapper; <%= yield %> is the rendered Markdown
│   ├── index.md          # home page (typically a post listing)
│   └── posts/
│       └── *.md          # one Markdown file per post
├── css/
│   └── **/*.{scss,css}   # concatenated and compiled to public/app.css
├── javascripts/
│   └── app.js            # copied to public/app.js
├── images/               # images referenced from pages are copied to public/images/
└── public/               # build output — serve/deploy this, don't edit it
```

## Writing posts

Posts are [kramdown](https://kramdown.gettalong.org/) Markdown with GitHub-style
fenced code blocks. A fresh blog ships `views/posts/post1.md` (headings, code,
math) and `views/posts/post2.md` (images, lists, tables, quotes) as worked
examples of everything below.

- **Headings** — `#` for the post title, `##` / `###` for sections.
- **Code** — inline with `` `backticks` ``; fenced blocks tagged with a language
  are syntax highlighted with [Rouge](https://github.com/rouge-ruby/rouge):

  ````
  ```ruby
  puts "hello"
  ```
  ````

  The theme is Monokai. Change `HIGHLIGHT_THEME` in `lib/parrot/constants.rb` to
  any Rouge theme name (`github`, `gruvbox`, `molokai`, …).
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
- **Internal links** — `[text](#post2.md)` is rewritten to `post2.html` during
  the build, so link posts to each other by their Markdown filename.

## Post header

Each post starts with an HTML comment holding its metadata (`parrot post` writes
this for you):

```
<!--
title: My new post title
date: 08/09/2026
-->
```

`title` becomes the page's `<title>` tag at build time. Set your site's URL once
in `views/layout.html.erb` — the `<meta property="og:url">` and
`<link rel="canonical">` tags — and Parrot rewrites both per page, appending the
built file's path (`https://example.com/post1.html`, `https://example.com/` for
the index).

## How `serve` rebuilds

- On startup Parrot hashes every source file. If the combined checksum differs
  from `public/.checksum` — or that file is missing — it runs a full build and
  then writes the new checksum. Otherwise it skips straight to serving the
  existing `public/`.
- While running, each saved file rebuilds only what it affects: a single post, a
  new/removed post, the compiled CSS, `app.js`, or a copied image. Editing
  `views/layout.html.erb` rebuilds the index and every post.
- `public/.checksum` is regenerated build state. It is gitignored and must not
  be deployed.

## Deployment

Run `parrot build` and upload the contents of `public/` to any static host —
GitHub Pages, Netlify, S3, nginx, and so on. Exclude `public/.checksum`.

## Development

```
$ bundle install
$ rspec                       # run the test suite
$ rspec -f d                  # documentation format
```

Run the suite from a directory that has no `blog/` folder — some specs create
and delete `./blog`.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Open a Pull Request

## License

MIT — see [LICENSE.txt](LICENSE.txt).
