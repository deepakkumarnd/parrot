<!--
title: About Parrot
date: 08/09/2026
-->

# About Parrot

Parrot turns a folder of Markdown into a static blog. This post is also a
cheat sheet: it shows the formatting you can use in any `views/posts/*.md`
file.

## Headings and text

Use `#` for the post title and `##` / `###` for sections, like the ones on
this page. Inline styles work too: **bold**, _italic_, and `inline code`.

## Code blocks

Tag a fenced block with a language and Parrot highlights it (Monokai theme by
default — change `HIGHLIGHT_THEME` in `lib/parrot/constants.rb`):

```ruby
class Greeter
  def initialize(name)
    @name = name
  end

  def greet
    puts "Hello, #{@name}!"
  end
end

Greeter.new("Parrot").greet
```

```bash
parrot new blog
cd blog
parrot serve
```

An untagged, indented block renders as plain preformatted text:

    $ parrot build

## Math

LaTeX between `$$ … $$` is rendered with MathJax. Inline, it flows with the
sentence: $$e^{i\pi} + 1 = 0$$.

On its own line it becomes a display block:

$$
W = W - \text{lr} \cdot \frac{\partial L}{\partial W}
$$

## Links between posts

Link to another post by its Markdown filename and Parrot rewrites it to the
built page at build time: [read the next post](#post2.md).
