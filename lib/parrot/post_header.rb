module Parrot
  # Reading a post's `<!-- key: value -->` comment header, shared by the
  # commands that look at posts: `build` and `list-tags` / `list-categories`.
  module PostHeader
    private

    # Reads the `<!-- key: value -->` comment header at the top of a post's
    # Markdown file into a Hash. Returns {} when the file has no such header.
    def post_metadata(post_path)
      header = File.read(post_path)[/\A\s*<!--(.+?)-->/m, 1]
      return {} unless header

      meta = header.each_line.with_object({}) do |line, meta|
        key, sep, value = line.partition(':')
        next if sep.empty?

        key = key.strip
        value = value.strip
        meta[key] = value unless key.empty? || value.empty?
      end

      meta['title']&.concat(' [Draft]') if draft_post?(meta)
      meta
    end

    def draft_post?(meta)
      meta['draft'] == 'true'
    end

    # "algorithms, coding" -> ["algorithms", "coding"]: the header's
    # comma-separated `tags`, trimmed, without blanks or duplicates.
    def post_tags(meta)
      meta['tags'].to_s.split(',').map(&:strip).reject(&:empty?).uniq
    end

    # A post's header `category`, trimmed, or nil when it has none.
    def post_category(meta)
      category = meta['category'].to_s.strip
      category.empty? ? nil : category
    end
  end
end
