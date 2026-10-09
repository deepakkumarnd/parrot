# Getting started

## Installation

Parrot needs Ruby 3.2 or newer (it is developed and tested on Ruby 4.0). It is
published on RubyGems as `prt`:

```sh
gem install prt
```

That puts the `parrot` command on your `PATH`. To pin the version per project
instead, add it to a `Gemfile`:

```ruby
gem 'prt'
```

then run `bundle install` and use `bundle exec parrot`.

## Create your first blog

```sh
parrot new blog                       # scaffold a blog from the skeleton
cd blog
parrot post --title "Hello world"     # add a post; it's listed on the index automatically
parrot serve                          # build, serve on http://localhost:8000 and rebuild on change
```

For a one-off build without the server:

```sh
parrot build                          # writes the site into ./public
```

## Commands

| Command | What it does |
| --- | --- |
| `parrot new <dir>` | Copy the skeleton blog into `<dir>` (which must not already exist) |
| `parrot post --title "<title>"` | Create `views/posts/<slug>.md` with today's date |
| `parrot build` | Build the current blog into `public/` |
| `parrot serve` | Build, serve `public/` on port 8000, and watch for changes |
| `parrot list-tags` | List every tag used in `views/posts`, with how many posts use it |
| `parrot list-categories` | List every category used in `views/posts`, with how many posts use it |

Global flags: `-q` / `--quiet`, `-v` / `--version`, `-h` / `--help`.

`post`, `build`, `serve`, `list-tags` and `list-categories` work on the current
directory, so run them from the blog's root.

## Project layout

A new blog looks like this:

```
blog/
├── config.yaml            # listing settings, see Configuration
├── views/
│   ├── layout.html.erb    # page wrapper; <%= yield %> is the rendered Markdown
│   ├── 404.md             # built to public/404.html
│   ├── about.md           # built to public/about.html, linked from the nav
│   └── posts/
│       └── *.md           # one Markdown file per post
├── css/
│   └── **/*.{scss,css}    # concatenated and compiled to public/app.css
├── javascripts/
│   └── app.js             # copied to public/app.js
├── images/                # images used by pages are copied to public/images/
└── public/                # build output: deploy this, don't edit it
```

There's no `views/index.md`: the home page is generated at build time from
everything in `views/posts/*.md`.

## Next steps

- [Write your first post](writing-posts.md)
- [Set your site URL and name](customizing.md#set-your-site-url)
- [Deploy the site](deployment.md)
