# Configuration

Parrot reads `config.yaml` at the blog's root. It controls how posts are listed
on the index and category pages, and how dates are formatted. The file is
optional: a missing file, section or key falls back to the defaults below.

```yaml
post_listing:
  list_title: "Post listing"               # heading above the listing (page 1 only); "" omits it
  back_link_text: "← Back to all posts"     # link at the top of every post; "" omits it
  group_by: none                            # none | year | month
  # per_page: 10                            # posts per index page; unset or 0 = one page
  newer_link_text: "← Newer posts"          # pager links; "" omits that link
  older_link_text: "Older posts →"
  list_format: "{post_date} ~ [{post_title}]({post_link}) {post_category_tag}"

post_date_format:
  on_list: "%m/%Y"      # {post_date} inside list_format
  on_post: "%d/%m/%Y"   # {post_date} inside a post's own body
```

Changes to `config.yaml` are picked up by `parrot serve` without a restart.

## The index page

`public/index.html` is generated from every post in `views/posts/`, newest
first. There's nothing to edit by hand.

| Key | Default | What it does |
| --- | --- | --- |
| `list_title` | `"Post listing"` | Heading above the listing, on the first page only. `""` omits it. |
| `back_link_text` | `"← Back to all posts"` | Text of the link at the top of every post. `""` omits it. |
| `group_by` | `none` | `year` or `month` splits the listing under `## 2026` or `## September 2026` headings, newest first. |
| `list_format` | see above | Markdown template for each post's entry. See [`list_format`](#list_format). |

## Pagination

| Key | Default | What it does |
| --- | --- | --- |
| `per_page` | unset | Maximum posts per index page. Unset or `0` keeps every post on `index.html`. |
| `newer_link_text` | `"← Newer posts"` | Text of the pager link to newer posts. `""` omits it. |
| `older_link_text` | `"Older posts →"` | Text of the pager link to older posts. `""` omits it. |

With `per_page` set, `index.html` holds the newest posts, followed by
`index2.html`, `index3.html` and so on, each with a pager at the bottom. Every
index page is listed in `sitemap.xml`, and a page that's no longer needed is
removed when the number of posts drops.

## `list_format`

A Markdown template applied to each post in a listing:

| Token | Expands to |
| --- | --- |
| `{post_<key>}` | That key from the post's header, as plain text: `{post_title}`, `{post_lang}`, `{post_tags}`, or any custom field you add. |
| `{post_date}` | The header's `date`, formatted with `post_date_format.on_list`. |
| `{post_category_tag}` | The post's category as an `<a class="category-tag">` link to its category page; empty when it has none. |
| `{post_link}` | The post's URL. Wrap the part that should be clickable in a Markdown link yourself. |
| `{…}` | Anything else is a Ruby [`strftime`](https://ruby-doc.org/3.2.2/Date.html#method-i-strftime) format applied to the header's `date`, e.g. `{%A, %B %d %Y}`. |

Examples:

```yaml
# Link just the title, and show the category (default)
list_format: "{post_date} ~ [{post_title}]({post_link}) {post_category_tag}"

# Make the whole line a link
list_format: "[{post_date} ~ {post_title}]({post_link})"

# Hide categories in listings
list_format: "{post_date} ~ [{post_title}]({post_link})"
```

## Date formats

`post_date_format.on_list` and `post_date_format.on_post` are Ruby `strftime`
format strings. `on_list` formats `{post_date}` in `list_format`; `on_post`
formats `{post_date}` inside a post's body and the date shown under each post's
title.

## Categories

Give a post one category in its header (`category: Ruby`) and the build adds:

- **`category-ruby.html`**, listing that category's posts, newest first. It uses
  the same `list_format`, `group_by` and pager as the index. Past `per_page`
  posts, the listing continues on `category-ruby_2.html`,
  `category-ruby_3.html`, and so on.
- **`categories.html`**, linked from the nav, listing every category with its
  post count (`<ul class="category-list">`).
- A link to the category under the post's title, and in listings through
  `{post_category_tag}`.

Page names come from the category name, lowercased, with spaces turned into
hyphens and anything other than letters, digits and hyphens dropped. Names that
end up the same (such as "C++" and "C") share one page, and the build warns
about it. Category pages are listed in `sitemap.xml`.
