require 'date'
require 'time'
require 'json'
require 'tilt'
require 'nokogiri'
require 'sassc'
require 'tilt/kramdown'
require 'kramdown-parser-gfm'
require 'rouge'

module Parrot

  module Commands

    # Build command builds the HTML static app
    # @usage  parrot build
    # The build files will be kept in the build directory
    class BuildCommand

      # Wraps rouge's class-tagged <span> output in <pre><code>, same markup
      # kramdown's default (deprecated) HTMLLegacy formatter produced.
      class CodeFormatter < Rouge::Formatters::HTML
        def initialize(opts = {})
          super()
          @wrap = opts.fetch(:wrap, true)
          @css_class = opts.fetch(:css_class, 'highlight')
        end

        def stream(tokens, &block)
          yield %(<div class="highlight"><pre class="#{@css_class}"><code>) if @wrap
          super
          yield '</code></pre></div>' if @wrap
        end
      end

      attr_accessor :app_root, :config, :build_path

      def initialize(args = [], config)
        @config = config
        @args = args
        @app_root = @config.root_dir
        @build_path = File.join(app_root, "public")
      end

      def build_index_page
        layout = Tilt.new("#{app_root}/views/layout.html.erb")

        text = layout.render do
          index = Tilt.new("#{app_root}/views/index.md")
          index.render
        end

        html = update_internal_links(text)
        copy_image_assets(html)
        apply_page_meta(html, "index.html")

        output = File.join(build_path, "index.html")
        File.write(output, html)
        config.logger.info "Built #{output}"
      end

      def build_posts
        Dir["#{app_root}/views/posts/*.md"].each { |post_path| build_post(post_path) }
      end

      # Builds public/404.html from views/404.md for hosts that serve it on a
      # missing path. Marked noindex; not listed in the sitemap or feed.
      def build_404_page
        source = File.join(app_root, "views", "404.md")
        return unless File.exist?(source)

        layout = Tilt.new("#{app_root}/views/layout.html.erb")
        html = update_internal_links(layout.render { markdown(source).render })
        copy_image_assets(html)

        title = html.at("head title")
        title.content = "Page not found" if title

        robots = Nokogiri::XML::Node.new("meta", html)
        robots["name"] = "robots"
        robots["content"] = "noindex"
        (html.at("head") || html).add_child(robots)

        output = File.join(build_path, "404.html")
        File.write(output, html)
        config.logger.info "Built #{output}"
      end

      def build_post(post_path)
        layout = Tilt.new("#{app_root}/views/layout.html.erb")

        body = markdown(post_path).render
        text = layout.render { body }

        html = update_internal_links(text)
        copy_image_assets(html)
        html = inject_scripts(html)

        output_name = File.basename(post_path).sub('.md', '.html')
        meta = post_metadata(post_path)
        meta["description"] ||= summarize(body)
        apply_page_meta(html, output_name, meta)

        output = File.join(build_path, output_name)
        File.write(output, html)
        config.logger.info "Built #{output}"
      end

      def update_internal_links(text)
        html = Nokogiri::HTML(text)

        html.css("a").each do |link|
          if link['href'].start_with?("#") && link['href'].end_with?(".md")
            link['href'] = link['href'][1..].sub('.md', '.html')
          end
        end

        html
      end

      def inject_scripts(html)
        script_tag = Nokogiri::XML::Node.new("script", html)
        script_tag['src'] = MATHJAX_URL
        script_tag['async'] = 'true' # optional attribute
        script_tag.content = "" # Needed to close the tag properly
        # Append the <script> tag to the <body>
        html.at('body') << script_tag
        html
      end

      def copy_image_assets(html)
        html.css("img, link").each do |node|
          # <img> carries the path in src, <link> (icons, favicons) in href.
          src = node["src"] || node["href"]
          next if src.nil?

          source_path = File.join(app_root, src)

          if src.start_with?("images/") && File.exist?(source_path)
            copy_image(source_path)
          end
        end
      end

      def copy_image(source_path)
        target_dir = File.join(build_path, "images")
        FileUtils.mkdir_p(target_dir)
        FileUtils.cp(source_path, target_dir)
        config.logger.info "Copied #{File.basename(source_path)} to #{target_dir}"
      end

      def compile_css
        css_files = Dir[File.join(app_root, "css", '**', '*.{scss,css}')]
        combined_scss = css_files.map { |file| File.read(file) }.join("\n")

        user_css =
          begin
            SassC::Engine.new(combined_scss, style: :compressed, syntax: :scss).render
          rescue SassC::SyntaxError => e
            puts "SassC Compilation Error: #{e.message}"
            ""
          end

        # The syntax-highlight theme must always ship, even when the user's
        # own stylesheet is empty or fails to compile.
        compiled_css = "#{user_css}\n#{syntax_highlight_css}"

        target_path = File.join(build_path, "app.css")
        File.write(target_path, compiled_css)
        config.logger.info "Compiled and minified CSS written to #{target_path}"
      end

      def compile_js
        FileUtils.cp(File.join(app_root, "javascripts", "app.js"), File.join(build_path))
        config.logger.info "Copied app.js to #{build_path}"
      end
      
      def run
        config.logger.info "Building application at #{app_root}"
        FileUtils.rm_rf('public')
        FileUtils.mkdir('public')
        build_index_page
        build_posts
        build_404_page
        build_sitemap
        build_robots
        build_feed
        compile_css
        compile_js
      end

      # Writes public/sitemap.xml listing the index and every post, each URL
      # built from the layout's base URL. Posts carry a <lastmod> from their
      # header `date`; the index carries the newest post's date. Skipped when
      # the layout declares no base URL.
      def build_sitemap
        base = site_base_url
        unless base
          config.logger.info "No og:url/canonical in the layout, skipping sitemap.xml"
          return
        end

        posts = Dir["#{app_root}/views/posts/*.md"].sort
        post_dates = posts.map { |post_path| iso_date(post_metadata(post_path)["date"]) }.compact

        entries = [{ loc: "#{base}/", lastmod: post_dates.max }]
        posts.each do |post_path|
          name = File.basename(post_path).sub(".md", ".html")
          entries << { loc: "#{base}/#{name}", lastmod: iso_date(post_metadata(post_path)["date"]) }
        end

        xml = +%(<?xml version="1.0" encoding="UTF-8"?>\n)
        xml << %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
        entries.each do |entry|
          xml << "  <url>\n    <loc>#{xml_escape(entry[:loc])}</loc>\n"
          xml << "    <lastmod>#{entry[:lastmod]}</lastmod>\n" if entry[:lastmod]
          xml << "  </url>\n"
        end
        xml << "</urlset>\n"

        output = File.join(build_path, "sitemap.xml")
        File.write(output, xml)
        config.logger.info "Built #{output}"
      end

      # Writes public/robots.txt allowing everything and pointing crawlers at
      # the sitemap (when the layout gives us a base URL to build its address).
      def build_robots
        base = site_base_url
        lines = ["User-agent: *", "Allow: /"]
        lines << "Sitemap: #{base}/sitemap.xml" if base

        output = File.join(build_path, "robots.txt")
        File.write(output, lines.join("\n") + "\n")
        config.logger.info "Built #{output}"
      end

      # Writes public/feed.xml (RSS 2.0), newest post first. Channel details come
      # from the layout; each item's description is its header `description` or
      # first paragraph. Skipped when the layout declares no base URL.
      def build_feed
        base = site_base_url
        unless base
          config.logger.info "No og:url/canonical in the layout, skipping feed.xml"
          return
        end

        layout_html = Nokogiri::HTML(Tilt.new("#{app_root}/views/layout.html.erb").render { "" })
        channel_title = meta_content(layout_html, 'meta[property="og:site_name"]') || "Parrot"
        channel_desc = meta_content(layout_html, 'meta[name="description"]') || ""

        items = Dir["#{app_root}/views/posts/*.md"].map do |post_path|
          meta = post_metadata(post_path)
          url = "#{base}/#{File.basename(post_path).sub('.md', '.html')}"
          {
            title: meta["title"] || File.basename(post_path, ".md"),
            url: url,
            description: meta["description"] || summarize(markdown(post_path).render) || "",
            iso: iso_date(meta["date"]),
            pub_date: rfc822_date(meta["date"])
          }
        end
        items.sort_by! { |item| item[:iso] || "" }
        items.reverse!

        xml = +%(<?xml version="1.0" encoding="UTF-8"?>\n)
        xml << %(<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">\n)
        xml << "  <channel>\n"
        xml << "    <title>#{xml_escape(channel_title)}</title>\n"
        xml << "    <link>#{base}/</link>\n"
        xml << "    <description>#{xml_escape(channel_desc)}</description>\n"
        xml << %(    <atom:link href="#{base}/feed.xml" rel="self" type="application/rss+xml"/>\n)
        items.each do |item|
          xml << "    <item>\n"
          xml << "      <title>#{xml_escape(item[:title])}</title>\n"
          xml << "      <link>#{item[:url]}</link>\n"
          xml << "      <guid isPermaLink=\"true\">#{item[:url]}</guid>\n"
          xml << "      <pubDate>#{item[:pub_date]}</pubDate>\n" if item[:pub_date]
          xml << "      <description>#{xml_escape(item[:description])}</description>\n"
          xml << "    </item>\n"
        end
        xml << "  </channel>\n</rss>\n"

        output = File.join(build_path, "feed.xml")
        File.write(output, xml)
        config.logger.info "Built #{output}"
      end

      # Rebuild a single file. Used by the file watcher, so `file` may be an
      # existing watched file or one that was just added; it may be given as an
      # absolute path or relative to the app root, as a String or as the
      # MatchData watchr hands its callbacks. The build strategy is picked from
      # where the file lives.
      def build(file)
        config.logger.info "Building changed file at #{file}"
        path = File.expand_path(file.to_s, app_root)
        relative = path.sub(%r{\A#{Regexp.escape(app_root)}/?}, "")

        FileUtils.mkdir_p(build_path)

        case relative
        when "views/layout.html.erb"
          # The layout wraps every page, so everything is rebuilt. Its base URL
          # feeds the sitemap, robots.txt and feed too.
          build_index_page
          build_posts
          build_404_page
          build_sitemap
          build_robots
          build_feed
        when "views/index.md"
          build_index_page
        when "views/404.md"
          build_404_page
        when %r{\Aviews/posts/[^/]+\.md\z}
          File.exist?(path) ? build_post(path) : remove_built_post(path)
          # A post was added, removed or had its date/summary changed.
          build_sitemap
          build_feed
        when %r{\Acss/.+\.(scss|css)\z}
          # css is concatenated before compiling, so a single change recompiles all.
          compile_css
        when "javascripts/app.js"
          compile_js
        when %r{\Aimages/[^/]+\z}
          copy_image(path) if File.exist?(path)
        else
          config.logger.info "No build strategy for #{relative}, skipping"
        end
      end

      private

      # Reads the `<!-- key: value -->` comment header at the top of a post's
      # Markdown file into a Hash. Returns {} when the file has no such header.
      def post_metadata(post_path)
        header = File.read(post_path)[/\A\s*<!--(.+?)-->/m, 1]
        return {} unless header

        header.each_line.each_with_object({}) do |line, meta|
          key, sep, value = line.partition(":")
          next if sep.empty?

          key = key.strip
          value = value.strip
          meta[key] = value unless key.empty? || value.empty?
        end
      end

      # Sets the per-page <html lang>, <title>, <meta property="og:*"> and
      # <link rel="canonical"> on the built HTML, and turns a relative og:image
      # path into an absolute URL (copying the file into the build). The site's
      # base URL comes from the layout (its canonical/og:url tag); the generated
      # file's path is appended so each page points at itself. `meta` is the
      # post's header Hash (empty for the index).
      def apply_page_meta(html, output_name, meta = {})
        title = meta["title"]
        is_post = output_name != "index.html"

        if title && !title.empty?
          title_tag = html.at("head title")
          title_tag.content = title if title_tag
        end

        lang = meta["lang"]
        if lang && !lang.empty?
          root = html.at("html")
          root["lang"] = lang if root
        end

        base = canonical_base(html)
        return unless base

        page_url = is_post ? "#{base}/#{output_name}" : "#{base}/"

        og = html.at('head meta[property="og:url"]')
        og["content"] = page_url if og

        canonical = html.at('head link[rel="canonical"]')
        canonical["href"] = page_url if canonical

        page_title = html.at("head title")&.text
        og_title = html.at('head meta[property="og:title"]')
        og_title["content"] = page_title if og_title && page_title && !page_title.empty?

        apply_description(html, meta["description"])
        apply_locale(html, meta["lang"])
        apply_article_meta(html, meta) if is_post

        resolve_og_image(html, base)

        feed = html.at('head link[rel="alternate"][type="application/rss+xml"]')
        feed["href"] = "#{base}/feed.xml" if feed && !feed["href"].to_s.start_with?("http")

        inject_json_ld(html, is_post, meta, page_url)
      end

      # Fills <meta name="description">, og:description and twitter:description
      # from one string (the post header's `description` or its first paragraph).
      def apply_description(html, description)
        return if description.nil? || description.empty?

        ['meta[name="description"]',
         'meta[property="og:description"]',
         'meta[name="twitter:description"]'].each do |selector|
          node = html.at("head #{selector}")
          node["content"] = description if node
        end
      end

      # Maps the page's `lang` onto og:locale (en -> en_US, ml -> ml_IN, …).
      def apply_locale(html, lang)
        node = html.at('head meta[property="og:locale"]')
        return unless node && lang && !lang.empty?

        locales = { "en" => "en_US", "ml" => "ml_IN", "hi" => "hi_IN", "ta" => "ta_IN" }
        node["content"] = locales.fetch(lang, lang)
      end

      # Adds a schema.org JSON-LD block: BlogPosting for a post, WebSite for the
      # index. Values are read back from the <head> this method has just filled.
      def inject_json_ld(html, is_post, meta, page_url)
        site_name = meta_content(html, 'meta[property="og:site_name"]')
        description = meta_content(html, 'meta[name="description"]')

        data = {
          "@context" => "https://schema.org",
          "@type" => is_post ? "BlogPosting" : "WebSite",
          "url" => page_url
        }

        if is_post
          data["headline"] = html.at("head title")&.text || meta["title"]
          data["mainEntityOfPage"] = page_url
          data["inLanguage"] = meta["lang"] || "en"
          if (published = iso_date(meta["date"]))
            data["datePublished"] = published
            data["dateModified"] = published
          end
          data["description"] = description if description
          image = meta_content(html, 'meta[property="og:image"]')
          data["image"] = image if image&.start_with?("http")
          author = meta_content(html, 'meta[name="author"]')
          data["author"] = { "@type" => "Person", "name" => author } if author
          data["publisher"] = { "@type" => "Organization", "name" => site_name } if site_name
        else
          data["name"] = site_name || html.at("head title")&.text
          data["description"] = description if description
        end

        json = JSON.pretty_generate(data).gsub("</", "<\\/")
        (html.at("head") || html).add_child(%(<script type="application/ld+json">#{json}</script>))
      end

      # A description drawn from the post body: the first paragraph with at least
      # `minimum` characters (so a date byline or a "write your post here" stub
      # is skipped), whitespace-collapsed and trimmed to ~155 characters on a
      # word boundary. nil when nothing qualifies.
      def summarize(fragment, limit = 155, minimum = 40)
        para = Nokogiri::HTML(fragment.to_s)
                 .css("p")
                 .map { |node| node.text.gsub(/\s+/, " ").strip }
                 .find { |text| text.length >= minimum }
        return unless para
        return para if para.length <= limit

        "#{para[0, limit].sub(/\s+\S*\z/, '').rstrip}…"
      end

      def meta_content(html, selector)
        value = html.at("head #{selector}")&.[]("content")
        value unless value.nil? || value.empty?
      end

      # A post is an OG "article", not a "website"; add its publish date (from
      # the header's dd/mm/yyyy `date`) as article:published_time in ISO form.
      def apply_article_meta(html, meta)
        og_type = html.at('head meta[property="og:type"]')
        og_type["content"] = "article" if og_type

        published = iso_date(meta["date"])
        return unless published

        node = Nokogiri::XML::Node.new("meta", html)
        node["property"] = "article:published_time"
        node["content"] = published
        (html.at("head") || html).add_child(node)
      end

      # "31/12/2026" -> "2026-12-31"; nil for a blank or invalid value.
      def iso_date(value)
        day, month, year = value.to_s.strip.split("/")
        return unless day && month && year

        Date.new(year.to_i, month.to_i, day.to_i).iso8601
      rescue ArgumentError
        nil
      end

      # "31/12/2026" -> "Thu, 31 Dec 2026 00:00:00 -0000" for RSS <pubDate>.
      def rfc822_date(value)
        day, month, year = value.to_s.strip.split("/")
        return unless day && month && year

        Time.utc(year.to_i, month.to_i, day.to_i).rfc2822
      rescue ArgumentError
        nil
      end

      # Open Graph and Twitter require an absolute og:image URL. Rewrite a
      # relative images/… path against the site's base URL and copy the file
      # into the build; leave an already-absolute URL untouched. When the source
      # is local, also emit og:image:width/height so scrapers can lay the card
      # out without fetching the file first.
      def resolve_og_image(html, base)
        og_image = html.at('head meta[property="og:image"]')
        src = og_image && og_image["content"]
        return if src.nil? || src.empty? || src.start_with?("http://", "https://", "//")

        source_path = File.join(app_root, src)
        if src.start_with?("images/") && File.exist?(source_path)
          copy_image(source_path)

          if (dimensions = image_dimensions(source_path))
            set_head_meta(html, "og:image:width", dimensions[0].to_s)
            set_head_meta(html, "og:image:height", dimensions[1].to_s)
          end
        end

        og_image["content"] = "#{base}/#{src}"
      end

      # Sets <meta property="…">, adding the tag to <head> if it isn't there.
      def set_head_meta(html, property, content)
        node = html.at(%(head meta[property="#{property}"]))
        unless node
          node = Nokogiri::XML::Node.new("meta", html)
          node["property"] = property
          (html.at("head") || html).add_child(node)
        end
        node["content"] = content
      end

      # [width, height] of a PNG, JPEG or GIF, read from the file header only.
      # nil for anything else or an unreadable file.
      def image_dimensions(path)
        File.open(path, "rb") do |io|
          head = io.read(24) or return nil

          if head.byteslice(0, 8) == "\x89PNG\r\n\x1a\n".b
            head.byteslice(16, 8).unpack("N2")
          elsif head.byteslice(0, 3) == "GIF".b
            head.byteslice(6, 4).unpack("v2")
          elsif head.byteslice(0, 2) == "\xFF\xD8".b
            jpeg_dimensions(io)
          end
        end
      rescue SystemCallError
        nil
      end

      # Walks a JPEG's markers to the start-of-frame, which carries the size.
      def jpeg_dimensions(io)
        io.seek(2)
        loop do
          byte = io.getbyte
          return nil if byte.nil?
          next unless byte == 0xFF

          marker = io.getbyte
          marker = io.getbyte while marker == 0xFF
          return nil if marker.nil?

          # Standalone markers (RSTn, SOI, EOI, TEM) carry no length.
          next if marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)

          length = io.read(2)&.unpack1("n")
          return nil if length.nil?

          if marker >= 0xC0 && marker <= 0xCF && ![0xC4, 0xC8, 0xCC].include?(marker)
            frame = io.read(5) or return nil
            height, width = frame.byteslice(1, 4).unpack("n2")
            return [width, height]
          end

          io.seek(length - 2, IO::SEEK_CUR)
        end
      end

      # The site's base URL as declared in the layout, without a trailing slash.
      def canonical_base(html)
        node = html.at('head link[rel="canonical"]') || html.at('head meta[property="og:url"]')
        value = node && (node["href"] || node["content"])
        value && value.strip.chomp("/")
      end

      # Same base URL, read straight from the rendered layout — for build steps
      # (sitemap, robots) that aren't tied to one page.
      def site_base_url
        layout = Tilt.new("#{app_root}/views/layout.html.erb")
        canonical_base(Nokogiri::HTML(layout.render { "" }))
      end

      def xml_escape(text)
        text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end

      def remove_built_post(post_path)
        output = File.join(build_path, File.basename(post_path).sub('.md', '.html'))
        return unless File.exist?(output)

        File.delete(output)
        config.logger.info "Removed #{output}"
      end

      # Colour rules for the fenced code blocks kramdown/rouge produced. Scoped
      # to .highlighter-rouge (rouge's wrapper) so the theme's background and
      # token colours never leak onto inline `code` spans.
      def syntax_highlight_css
        theme = Rouge::Theme.find(HIGHLIGHT_THEME) || Rouge::Themes::Monokai
        [
          theme.render(scope: ".highlighter-rouge"),
          ".highlighter-rouge{margin:1rem 0;padding:1rem;overflow-x:auto;border-radius:6px}",
          ".highlighter-rouge pre,.highlighter-rouge code{margin:0;padding:0;background:none;border:0}"
        ].join("\n")
      end

      def markdown(file)
        # GFM so ```lang fences work; rouge tags every token in a fenced code
        # block with a class, which #syntax_highlight_css then colours.
        Tilt::KramdownTemplate.new(
          input: 'GFM',
          hard_wrap: false,
          syntax_highlighter: 'rouge',
          syntax_highlighter_opts: { formatter: CodeFormatter },
          math_engine: 'mathjax',
          math_engine_opts: { format: [:html] }
        ) do
          File.read(file)
        end
      end
    end
  end
end