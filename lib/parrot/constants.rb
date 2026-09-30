MATHJAX_URL = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js'.freeze

# Rouge theme used for syntax highlighting of code blocks in posts.
# Any theme name from Rouge::Themes works here (e.g. "monokai", "github",
# "gruvbox", "colorful", "molokai", "thankful_eyes").
HIGHLIGHT_THEME = 'monokai'.freeze

# `{post_<key>}` expands to that key from the post's header (so
# `{post_title}`, `{post_lang}`, or any custom header field), as plain
# text; `{post_date}` is the same header field but run through
# `post_date_format.on_list` below rather than shown as-authored.
# `{post_link}` is the one field Parrot computes itself rather than
# reading from the header: the post's href. Wrap whichever span should
# be clickable in ordinary Markdown link syntax, [...]({post_link}).
# This default links just the title:
#   "{post_date} ~ [{post_title}]({post_link})"
# To make the whole line a link instead:
#   "[{post_date} ~ {post_title}]({post_link})"
# A bare strftime format string like {%d/%m/%Y} also still works here,
# shown exactly as formatted rather than through post_date_format.
DEFAULT_LIST_FORMAT = '{post_date} ~ [{post_title}]({post_link})'.freeze
DEFAULT_GROUP_BY = 'none'.freeze
DEFAULT_LIST_TITLE = 'Post listing'.freeze
DEFAULT_BACK_LINK_TEXT = '← Back to all posts'.freeze
DEFAULT_NEWER_LINK_TEXT = '← Newer posts'.freeze
DEFAULT_OLDER_LINK_TEXT = 'Older posts →'.freeze

# `{post_date}` is the one header field with its own dedicated config,
# config.yaml's `post_date_format` — a Ruby strftime format string (see
# Date#strftime) per context: `on_list` when `{post_date}` appears in a
# post_listing `list_format`, `on_post` when it appears as a literal
# placeholder inside a post's own Markdown body.
DEFAULT_POST_DATE_FORMAT = { 'on_list' => '%m/%Y', 'on_post' => '%d/%m/%Y' }.freeze
