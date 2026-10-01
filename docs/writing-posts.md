# Writing posts

Each post is a Markdown file in `views/posts/`. Create one with:

```sh
parrot post --title "My new post"
```

This writes `views/posts/my-new-post.md`. The filename is the title in
lowercase, with spaces turned into hyphens and other punctuation dropped. It
won't overwrite an existing post.

A new blog ships two example posts: `views/posts/about_parrot.md` (headings,
code, math) and `views/posts/sample.md` (images, lists, tables, quotes).

## The post header

Each post starts with an HTML comment holding its metadata. `parrot post` writes
`title`, `date`, `lang` and an empty `category`; you can add the other fields
by hand:

```
<!--
title: My new post title
date: 08/09/2026
lang: en
category: Programming
description: One or two sentences for search results and social cards.
tags: algorithms, coding
draft: true
-->
```

| Field | Required | What it does |
| --- | --- | --- |
| `title` | yes | The page's `<title>` and `og:title`. Also fills `{post_title}` in the body. |
| `date` | yes | Publication date (`dd/mm/yyyy`). Orders the index and feeds the sitemap, feed and `article:published_time`. |
| `lang` | no | `<html lang="…">` and `og:locale` for this page. Set it per post (`ml`, `hi`, …) for posts in another language. |
| `category` | no | One category per post. See [Categories](configuration.md#categories). |
| `description` | no | `<meta name="description">`, `og:description` and `twitter:description`. Defaults to the post's first paragraph. |
| `tags` | no | Comma-separated. Listed at the bottom of the post and emitted as `article:tag` metas and JSON-LD `keywords`. |
| `draft` | no | `true` keeps the post out of `parrot build`. See [Drafts](#drafts). |

Any other field you add can be shown on the index with `{post_<field>}`; see
[`list_format`](configuration.md#list_format).

## Markdown

Posts are [kramdown](https://kramdown.gettalong.org/) Markdown with
GitHub-style fenced code blocks. If you're new to Markdown, the
[Markdown Guide](https://www.markdownguide.org/basic-syntax/) covers the basics.

### Headings

Use `#` for the post title and `##` / `###` for sections. `parrot post` starts
each post with `# {post_title}`, so the heading always matches the header's
`title`.

### Code

Inline code uses `` `backticks` ``. Fenced blocks tagged with a language are
syntax highlighted with [Rouge](https://github.com/rouge-ruby/rouge):

````
```ruby
puts "hello"
```
````

The highlighting theme is Monokai. See
[Syntax highlighting theme](customizing.md#syntax-highlighting-theme) to change it.

### Math

LaTeX between `$$ … $$` is rendered by MathJax. It's shown inline when it sits
inside a line of text, and as a display block when it's on its own line.

### Tables

GitHub-style pipe tables:

```
| Feature | Supported |
| ------- | --------- |
| Tables  | yes       |
```

### Blockquotes

A line starting with `>`:

```
> Blockquotes are good for asides and pull quotes.
```

### Images

Keep image files in `images/` and link them with a relative path
(`![A parrot](images/parrot.jpeg)`). Parrot copies only the images a page uses
into `public/images/`.

### Links between posts

Link to another post by its Markdown filename with a leading `#`:
`[read the next post](#sample.md)` becomes a link to `sample.html` in the build.

## Placeholders

| Placeholder | Replaced with |
| --- | --- |
| `{post_title}` | The header's `title`. |
| `{post_date}` | The header's `date`, formatted with `post_date_format.on_post` from [`config.yaml`](configuration.md#date-formats). |

## What the build adds to each post

- **Date and category line.** Under the post's `<h1>`, a
  `<p class="post-meta">` line shows the date and the category, which links to
  that category's page. Each part is left out if the header doesn't have it.
  Posts written by older versions of `parrot post` have a `_{post_date}_` line
  under the title; it's replaced by this line, so the date isn't shown twice.
- **Back link.** A `<p class="back-link">` link at the top of `<main>` goes back
  to the index page that lists the post (`index.html`, or `index2.html`, … when
  the index is paginated). Change or remove its text with
  [`back_link_text`](configuration.md#the-index-page).
- **Tags.** When the header has `tags`, they're listed at the bottom as
  `<p class="post-tags">Tags: <span class="tag">algorithms</span> …</p>`.

Style these with the `.post-meta`, `.category-tag`, `.back-link`, `.post-tags`
and `.tag` classes in your CSS.

## Drafts

Add `draft: true` to a post's header to keep it unpublished. `parrot build`
skips drafts entirely: no page, and nothing in the index, `sitemap.xml` or
`feed.xml`. `parrot serve` builds and lists them so you can preview them.

## Reserved names

`about`, `404`, `index`, `index2`, `index3`, …, `categories`, `category`, `now`,
`post`, `posts`, `note` and `notes` can't be used as post names. Some would
overwrite pages Parrot generates; the rest are kept free for future pages. The
check ignores case. `parrot post` refuses such a title, and `parrot build`
fails if one is in `views/posts/`. A post also can't be named after a category
page the build writes, such as `category-ruby.md`.
