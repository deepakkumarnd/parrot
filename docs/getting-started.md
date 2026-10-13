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
| `parrot copy-assets` | Copy in skeleton styles and icons the blog doesn't have yet, without overwriting any |

Global flags: `-q` / `--quiet`, `-v` / `--version`, `-h` / `--help`.

`post`, `build`, `serve`, `list-tags`, `list-categories` and `copy-assets` work
on the current directory, so run them from the blog's root.

## Project layout

A new blog looks like this:

```
blog/
├── config.yaml            # listing settings, see Configuration
├── views/
│   ├── layout.html.erb    # page wrapper; <%= yield %> is the rendered Markdown
│   ├── 404.md             # built to public/404.html
│   ├── menu/
│   │   └── *.md           # about, now, projects, apps, photos: built to
│   │                      #   public/<name>.html, linked from the nav's menu
│   └── posts/
│       └── *.md           # one Markdown file per post
├── css/
│   ├── _search.scss       # styles for the search box, copy button and menu,
│   ├── _copy_code.scss    #   compiled first
│   ├── _menu.scss
│   └── **/*.{scss,css}    # concatenated and compiled to public/app.css
├── javascripts/
│   └── app.js             # added to public/app.js
├── images/                # images used by pages are copied to public/images/
└── public/                # build output: deploy this, don't edit it
```

There's no `views/index.md`: the home page is generated at build time from
everything in `views/posts/*.md`.

## Copying new assets

Newer versions of Parrot sometimes add styles or icons to the skeleton, such as
the menu's `css/_menu.scss`. A blog made by an older version doesn't have them,
so the build uses Parrot's own copies. To edit them, run `parrot copy-assets` in
the blog: it copies in every skeleton style and icon the blog is missing, and
never overwrites a file you have. Scripts aren't copied; Parrot puts them into
every build itself.

## Next steps

- [Write your first post](writing-posts.md)
- [Set your site URL and name](customizing.md#set-your-site-url)
- [Deploy the site](deployment.md)
