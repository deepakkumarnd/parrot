require 'date'
require 'time'
require 'json'
require 'yaml'
require 'tilt'
require 'nokogiri'
require 'sassc'
require 'tilt/kramdown'
require 'kramdown-parser-gfm'
require 'rouge'
require_relative '../post_header'
require_relative '../search_index'

module Parrot
  module Commands
    # Build command builds the HTML static app
    # @usage  parrot build
    # The build files will be kept in the build directory
    class BuildCommand
      include PostHeader

      # Wraps rouge's class-tagged <span> output in <pre><code>, same markup
      # kramdown's default (deprecated) HTMLLegacy formatter produced.
      class CodeFormatter < Rouge::Formatters::HTML
        def initialize(opts = {})
          super()
          @wrap = opts.fetch(:wrap, true)
          @css_class = opts.fetch(:css_class, 'highlight')
        end

        def stream(tokens, &)
          yield %(<div class="highlight"><pre class="#{@css_class}"><code>) if @wrap
          super
          yield '</code></pre></div>' if @wrap
        end
      end

      # Files the gem ships into every build, not part of the user's blog.
      ASSETS_DIR = File.expand_path('../assets', __dir__)

      attr_accessor :app_root, :config, :build_path

      def initialize(args = [], config)
        @config = config
        @args = args
        @app_root = @config.root_dir
        @build_path = File.join(app_root, 'public')
        set_build_mode!
      end

      def unset_build_mode!
        @config[:build_mode] = false
      end

      def set_build_mode!
        @config[:build_mode] = true
      end

      # Builds index.html and, once there are more posts than post_listing's
      # per_page, index2.html, index3.html, etc. — newest posts first, oldest
      # posts on the highest-numbered page. Any previously-built index page
      # beyond the current page count is removed, so a shrinking post count
      # doesn't leave a stale trailing page behind.
      def build_index_page
        pages = paginated_posts(sorted_posts_metadata)

        pages.each_with_index do |posts_meta, index|
          build_index_file(index + 1, posts_meta, pages.length)
        end

        cleanup_stale_index_pages(pages.length)
      end

      def build_index_file(page_number, posts_meta, total_pages)
        layout = Tilt.new("#{app_root}/views/layout.html.erb")

        text = layout.render { markdown_string(index_markdown(page_number, posts_meta, total_pages)).render }

        html = update_internal_links(text)
        copy_image_assets(html)
        inject_search(html)
        apply_page_meta(html, index_filename(page_number))

        output = File.join(build_path, index_filename(page_number))
        File.write(output, html)
        config.logger.info "Built #{output}"
      end

      # Builds category-<slug>.html for every category in use, plus
      # category-<slug>_2.html, _3, … once a category has more posts than
      # post_listing's per_page. Each lists just that category's posts, newest
      # first, with the same list_format, group_by and pager as the index.
      # Any category-*.html this build didn't write (a category no post uses
      # any more, or a trailing page it no longer needs) is removed, unless
      # it's a post's own page (category-theory.md when no such category
      # exists).
      def build_category_pages
        keep = sorted_posts_metadata.map { |meta| meta['__filename'].sub('.md', '.html') }
        keep += posts_by_category.flat_map do |slug, category|
          pages = paginated_posts(category[:posts])
          pages.each_with_index.map do |posts_meta, index|
            build_category_file(slug, category[:name], index + 1, posts_meta, pages.length)
          end
        end

        Dir[File.join(build_path, 'category-*.html')].each do |path|
          File.delete(path) unless keep.include?(File.basename(path))
        end
      end

      # Writes one category listing page and returns its filename. Every page
      # repeats the category's name as its heading, so a visitor several
      # pages in still knows which category they're browsing.
      def build_category_file(slug, name, page_number, posts_meta, total_pages)
        layout = Tilt.new("#{app_root}/views/layout.html.erb")
        filename = category_filename(slug, page_number)

        markdown = "### #{escape_markdown(name)}\n\n#{render_post_listing(posts_meta)}\n"
        pager = pager_markdown(page_number, total_pages, ->(number) { category_filename(slug, number) })
        markdown << "\n#{pager}\n" unless pager.empty?

        html = update_internal_links(layout.render { markdown_string(markdown).render })
        copy_image_assets(html)
        inject_search(html)

        title = page_number == 1 ? "#{name} posts" : "#{name} posts (page #{page_number})"
        meta = { 'title' => title, 'description' => "Posts filed under #{name}." }
        apply_page_meta(html, filename, meta, kind: :category)

        output = File.join(build_path, filename)
        File.write(output, html)
        config.logger.info "Built #{output}"
        filename
      end

      # Builds public/categories.html, the page the layout's nav links to:
      # every category in use, by name, linking its listing, with its post
      # count. Written even when no post has a category yet, so that nav link
      # never 404s.
      def build_categories_page
        entries = posts_by_category.map do |slug, category|
          "- [#{escape_markdown(category[:name])}](#{category_filename(slug, 1)}) (#{category[:posts].length})"
        end
        listing = entries.empty? ? 'No categories yet.' : "#{entries.join("\n")}\n{: .category-list}"

        layout = Tilt.new("#{app_root}/views/layout.html.erb")
        html = update_internal_links(layout.render { markdown_string("### Categories\n\n#{listing}\n").render })
        copy_image_assets(html)
        inject_search(html)
        meta = { 'title' => 'Categories', 'description' => 'Every category on this blog.' }
        apply_page_meta(html, 'categories.html', meta, kind: :category)

        output = File.join(build_path, 'categories.html')
        File.write(output, html)
        config.logger.info "Built #{output}"
      end

      # Rebuilds every post, each linking its back-link at whichever index
      # page it currently falls on — which can shift for posts far from the
      # top whenever pagination is active and a post is added, removed, or
      # re-dated, so every post is rebuilt together rather than in isolation.
      def build_posts
        posts_meta = sorted_posts_metadata
        page_lookup = page_number_lookup(posts_meta)

        published_post_paths.each do |post_path|
          build_post(post_path, page_lookup.fetch(File.basename(post_path), 1))
        end
      end

      # Builds public/404.html from views/404.md for hosts that serve it on a
      # missing path. Marked noindex; not listed in the sitemap or feed.
      def build_404_page
        source = File.join(app_root, 'views', '404.md')
        return unless File.exist?(source)

        layout = Tilt.new("#{app_root}/views/layout.html.erb")
        html = update_internal_links(layout.render { markdown(source).render })
        copy_image_assets(html)
        inject_search(html)

        title = html.at('head title')
        title.content = 'Page not found' if title

        robots = Nokogiri::XML::Node.new('meta', html)
        robots['name'] = 'robots'
        robots['content'] = 'noindex'
        (html.at('head') || html).add_child(robots)

        output = File.join(build_path, '404.html')
        File.write(output, html)
        config.logger.info "Built #{output}"
      end

      # Builds public/about.html from views/about.md, the page the layout's nav
      # links to. It takes the same optional `<!-- key: value -->` header as a
      # post (title, description, lang) but isn't one: it stays out of the
      # index listing and the feed, and is listed in the sitemap. A previously
      # built page is removed once views/about.md is gone.
      def build_about_page
        source = File.join(app_root, 'views', 'about.md')
        output = File.join(build_path, 'about.html')

        unless File.exist?(source)
          FileUtils.rm_f(output)
          return
        end

        meta = post_metadata(source)
        layout = Tilt.new("#{app_root}/views/layout.html.erb")
        body = markdown(source).render

        html = update_internal_links(layout.render { body })
        copy_image_assets(html)
        inject_search(html)

        meta['title'] ||= html.at('main h1')&.text
        meta['description'] ||= summarize(body)
        apply_page_meta(html, 'about.html', meta, kind: :about)

        File.write(output, html)
        config.logger.info "Built #{output}"
      end

      def build_post(post_path, page_number = 1)
        meta = post_metadata(post_path)
        return if build_mode? && draft_post?(meta)

        layout = Tilt.new("#{app_root}/views/layout.html.erb")

        meta['__date'] = parse_post_date(meta['date'])

        source = substitute_post_date(File.read(post_path), meta)
        source = substitute_post_title(source, meta)
        body = markdown_string(source).render
        text = layout.render { body }

        html = update_internal_links(text)
        copy_image_assets(html)
        inject_search(html)
        html = inject_scripts(html)
        html = inject_post_meta(html, meta)
        html = inject_back_link(html, page_number)
        html = inject_tags(html, post_tags(meta))

        output_name = File.basename(post_path).sub('.md', '.html')
        meta['description'] ||= summarize(body)
        apply_page_meta(html, output_name, meta)

        output = File.join(build_path, output_name)
        File.write(output, html)
        config.logger.info "Built #{output}"
      end

      def update_internal_links(text)
        html = Nokogiri::HTML(text)

        html.css('a').each do |link|
          link['href'] = link['href'][1..].sub('.md', '.html') if link['href'].start_with?('#') && link['href'].end_with?('.md')
        end

        html
      end

      def inject_scripts(html)
        script_tag = Nokogiri::XML::Node.new('script', html)
        script_tag['src'] = MATHJAX_URL
        script_tag['async'] = 'true' # optional attribute
        script_tag.content = '' # Needed to close the tag properly
        # Append the <script> tag to the <body>
        html.at('body') << script_tag
        html
      end

      # Adds a link back to the index above a post's own content, so a
      # visitor who lands directly on a post can get back to the listing —
      # specifically to whichever index page currently lists this post,
      # since pagination can put it anywhere. Its text comes from
      # config.yaml's post_listing.back_link_text, omitted entirely when
      # that's explicitly set to an empty string.
      def inject_back_link(html, page_number = 1)
        settings = post_listing_settings
        return html if settings.key?('back_link_text') && settings['back_link_text'].to_s.strip.empty?

        main = html.at('main')
        return html unless main

        link = Nokogiri::XML::Node.new('a', html)
        link['href'] = index_filename(page_number)
        link.content = settings['back_link_text'] || DEFAULT_BACK_LINK_TEXT

        paragraph = Nokogiri::XML::Node.new('p', html)
        paragraph['class'] = 'back-link'
        paragraph.add_child(link)

        main.prepend_child(paragraph)
        html
      end

      # Puts a `<p class="post-meta">` line right after the post's <h1> (or at
      # the top of its <main> when it has none): its header `date`, formatted
      # per post_date_format.on_post, and its `category` as a
      # `<a class="category-tag">` link to that category's listing. Either is
      # left out when the header doesn't have it, and the line when neither is
      # there. A paragraph right after the <h1> holding nothing but that same
      # date — the `_{post_date}_` line `parrot post` used to write — is
      # replaced, so the date isn't shown twice.
      def inject_post_meta(html, meta)
        date = meta['__date']&.strftime(post_date_format('on_post'))
        href = category_href(meta)
        return html if date.nil? && href.nil?

        main = html.at('main')
        return html unless main

        paragraph = Nokogiri::XML::Node.new('p', html)
        paragraph['class'] = 'post-meta'

        if date
          time = Nokogiri::XML::Node.new('time', html)
          time['datetime'] = meta['__date'].iso8601
          time.content = date
          paragraph.add_child(time)
        end

        if href
          paragraph.add_child(Nokogiri::XML::Text.new(' · ', html)) if date
          link = Nokogiri::XML::Node.new('a', html)
          link['class'] = 'category-tag'
          link['href'] = href
          link.content = post_category(meta)
          paragraph.add_child(link)
        end

        heading = main.at('h1')
        following = heading&.next_element
        if heading.nil?
          main.prepend_child(paragraph)
        elsif date && following&.name == 'p' && following.text.strip == date
          following.replace(paragraph)
        else
          heading.add_next_sibling(paragraph)
        end

        html
      end

      # Lists a post's header `tags` at the bottom of its <main>, each in its
      # own <span class="tag">. Nothing is added for a post without tags.
      def inject_tags(html, tags)
        return html if tags.empty?

        main = html.at('main')
        return html unless main

        paragraph = Nokogiri::XML::Node.new('p', html)
        paragraph['class'] = 'post-tags'
        paragraph.add_child(Nokogiri::XML::Text.new('Tags: ', html))

        tags.each_with_index do |tag, index|
          paragraph.add_child(Nokogiri::XML::Text.new(' ', html)) if index.positive?
          span = Nokogiri::XML::Node.new('span', html)
          span['class'] = 'tag'
          span.content = tag
          paragraph.add_child(span)
        end

        main.add_child(paragraph)
        html
      end

      # Adds the search box and <script src="search.js"> to a page, unless
      # config.yaml turns search off. The box goes right after the header's
      # nav (or at the top of the header, or of <body>, for layouts without
      # one), hidden until search.js has wired it up.
      def inject_search(html)
        return html unless search_enabled?

        body = html.at('body')
        return html unless body

        container = Nokogiri::XML::Node.new('div', html)
        container['class'] = 'search'
        container['hidden'] = 'hidden'

        input = Nokogiri::XML::Node.new('input', html)
        input['class'] = 'search-input'
        input['type'] = 'search'
        input['placeholder'] = search_settings['placeholder'] || DEFAULT_SEARCH_PLACEHOLDER
        input['aria-label'] = 'Search posts'
        input['autocomplete'] = 'off'
        container.add_child(input)

        list = Nokogiri::XML::Node.new('ul', html)
        list['class'] = 'search-suggestions'
        list['id'] = 'search-suggestions'
        list['role'] = 'listbox'
        list['hidden'] = 'hidden'
        container.add_child(list)

        header = html.at('header.site-header') || html.at('header')
        nav = header&.at('nav')
        if nav
          nav.add_next_sibling(container)
        elsif header
          header.prepend_child(container)
        else
          body.prepend_child(container)
        end

        script = Nokogiri::XML::Node.new('script', html)
        script['src'] = 'search.js'
        script['defer'] = 'defer'
        script.content = '' # Needed to close the tag properly
        (html.at('head') || body).add_child(script)
        html
      end

      def copy_image_assets(html)
        html.css('img, link').each do |node|
          # <img> carries the path in src, <link> (icons, favicons) in href.
          src = node['src'] || node['href']
          next if src.nil?

          source_path = File.join(app_root, src)

          copy_image(source_path) if src.start_with?('images/') && File.exist?(source_path)
        end
      end

      def copy_image(source_path)
        target_dir = File.join(build_path, 'images')
        FileUtils.mkdir_p(target_dir)
        FileUtils.cp(source_path, target_dir)
        config.logger.info "Copied #{File.basename(source_path)} to #{target_dir}"
      end

      def compile_css
        css_files = Dir[File.join(app_root, 'css', '**', '*.{scss,css}')]
        combined_scss = css_files.map { |file| File.read(file) }.join("\n")

        user_css =
          begin
            SassC::Engine.new(combined_scss, style: :compressed, syntax: :scss).render
          rescue SassC::SyntaxError => e
            puts "SassC Compilation Error: #{e.message}"
            ''
          end

        # The syntax-highlight theme must always ship, even when the user's
        # own stylesheet is empty or fails to compile. The search box's
        # default styles go first, so the user's own rules override them.
        compiled_css = "#{user_css}\n#{syntax_highlight_css}"
        compiled_css = "#{File.read(File.join(ASSETS_DIR, 'search.css'))}\n#{compiled_css}" if search_enabled?

        target_path = File.join(build_path, 'app.css')
        File.write(target_path, compiled_css)
        config.logger.info "Compiled and minified CSS written to #{target_path}"
      end

      def compile_js
        FileUtils.cp(File.join(app_root, 'javascripts', 'app.js'), File.join(build_path))
        config.logger.info "Copied app.js to #{build_path}"
      end

      # Writes public/search.js: the browser-side search from
      # lib/parrot/assets/search.js with a trie of every published post's
      # title, tags and category baked in, so searching never touches the
      # network. Removed instead when config.yaml turns search off.
      def build_search
        output = File.join(build_path, 'search.js')
        unless search_enabled?
          FileUtils.rm_f(output)
          return
        end

        index = SearchIndex.new
        sorted_posts_metadata.each do |meta|
          index.add(
            title: meta['title'] || File.basename(meta['__filename'], '.md'),
            url: meta['__filename'].sub('.md', '.html'),
            keywords: [*post_tags(meta), *post_category(meta)]
          )
        end

        script = File.read(File.join(ASSETS_DIR, 'search.js'))
                     .sub('/*__PARROT_SEARCH_INDEX__*/null') { index.to_json }
                     .sub('/*__PARROT_SEARCH_LIMIT__*/10') { SEARCH_SUGGESTION_LIMIT.to_s }
        File.write(output, script)
        config.logger.info "Built #{output}"
      end

      def run
        config.logger.info "Building application at #{app_root}"
        reset_posts_metadata
        check_reserved_post_names!
        FileUtils.rm_rf('public')
        FileUtils.mkdir('public')
        build_index_page
        build_posts
        build_category_pages
        build_categories_page
        build_404_page
        build_about_page
        build_sitemap
        build_robots
        build_feed
        build_search
        compile_css
        compile_js
      ensure
        reset_posts_metadata
      end

      # Writes public/sitemap.xml listing the index, every post and category
      # page, and the about page, each URL
      # built from the layout's base URL. Posts carry a <lastmod> from their
      # header `date`; the index carries the newest post's date. Skipped when
      # the layout declares no base URL.
      def build_sitemap
        base = site_base_url
        unless base
          config.logger.warn 'No og:url/canonical in the layout, skipping sitemap.xml'
          return
        end

        posts = published_post_paths
        post_dates = posts.map { |post_path| iso_date(post_metadata(post_path)['date']) }.compact
        newest = post_dates.max

        total_pages = paginated_posts(sorted_posts_metadata).length
        entries = (1..total_pages).map do |page_number|
          loc = page_number == 1 ? "#{base}/" : "#{base}/#{index_filename(page_number)}"
          { loc: loc, lastmod: newest }
        end

        posts.each do |post_path|
          name = File.basename(post_path).sub('.md', '.html')
          entries << { loc: "#{base}/#{name}", lastmod: iso_date(post_metadata(post_path)['date']) }
        end

        entries << { loc: "#{base}/about.html" } if File.exist?(File.join(app_root, 'views', 'about.md'))

        entries << { loc: "#{base}/categories.html", lastmod: newest }
        posts_by_category.each do |slug, category|
          lastmod = category[:posts].filter_map { |meta| iso_date(meta['date']) }.max
          paginated_posts(category[:posts]).length.times do |index|
            entries << { loc: "#{base}/#{category_filename(slug, index + 1)}", lastmod: lastmod }
          end
        end

        xml = +%(<?xml version="1.0" encoding="UTF-8"?>\n)
        xml << %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
        entries.each do |entry|
          xml << "  <url>\n    <loc>#{xml_escape(entry[:loc])}</loc>\n"
          xml << "    <lastmod>#{entry[:lastmod]}</lastmod>\n" if entry[:lastmod]
          xml << "  </url>\n"
        end
        xml << "</urlset>\n"

        output = File.join(build_path, 'sitemap.xml')
        File.write(output, xml)
        config.logger.info "Built #{output}"
      end

      # Writes public/robots.txt allowing everything and pointing crawlers at
      # the sitemap (when the layout gives us a base URL to build its address).
      def build_robots
        base = site_base_url
        lines = ['User-agent: *', 'Allow: /']
        lines << "Sitemap: #{base}/sitemap.xml" if base

        output = File.join(build_path, 'robots.txt')
        File.write(output, "#{lines.join("\n")}\n")
        config.logger.info "Built #{output}"
      end

      # Writes public/feed.xml (RSS 2.0), newest post first. Channel details come
      # from the layout; each item's description is its header `description` or
      # first paragraph. Skipped when the layout declares no base URL.
      def build_feed
        base = site_base_url
        unless base
          config.logger.info 'No og:url/canonical in the layout, skipping feed.xml'
          return
        end

        layout_html = Nokogiri::HTML(Tilt.new("#{app_root}/views/layout.html.erb").render { '' })
        channel_title = meta_content(layout_html, 'meta[property="og:site_name"]') || 'Parrot'
        channel_desc = meta_content(layout_html, 'meta[name="description"]') || ''

        items = published_post_paths.map do |post_path|
          meta = post_metadata(post_path)
          url = "#{base}/#{File.basename(post_path).sub('.md', '.html')}"
          {
            title: meta['title'] || File.basename(post_path, '.md'),
            url: url,
            description: meta['description'] || summarize(markdown(post_path).render) || '',
            iso: iso_date(meta['date']),
            pub_date: rfc822_date(meta['date'])
          }
        end
        items.sort_by! { |item| item[:iso] || '' }
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

        output = File.join(build_path, 'feed.xml')
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
        relative = path.sub(%r{\A#{Regexp.escape(app_root)}/?}, '')
        reset_posts_metadata

        FileUtils.mkdir_p(build_path)

        case relative
        when 'views/layout.html.erb'
          # The layout wraps every page, so everything is rebuilt. Its base URL
          # feeds the sitemap, robots.txt and feed too.
          build_index_page
          build_posts
          build_category_pages
          build_categories_page
          build_404_page
          build_about_page
          build_sitemap
          build_robots
          build_feed
        when 'views/404.md'
          build_404_page
        when 'views/about.md'
          build_about_page
          build_sitemap
        when 'config.yaml'
          # post_listing settings change the index; post_date_format also
          # affects the {post_date} placeholder inside every post's own body.
          # per_page changes how many index pages there are, so the sitemap
          # listing them is rewritten too. Category pages share all of that.
          # search can be switched on or off, which touches every page, the
          # stylesheet and search.js itself.
          build_index_page
          build_posts
          build_category_pages
          build_categories_page
          build_404_page
          build_about_page
          build_sitemap
          build_search
          compile_css
        when %r{\Aviews/posts/[^/]+\.md\z}
          check_reserved_post_names!
          remove_built_post(path) unless File.exist?(path)
          # A post was added, removed or had its date/title/summary changed,
          # any of which can change the generated index listing and, when
          # pagination is active, shift other posts onto a different index
          # page — so every post is rebuilt to keep back-links correct. Its
          # category may have changed too, so category pages are rebuilt, and
          # its title, tags or category may have changed the search index.
          build_posts
          build_index_page
          build_category_pages
          build_categories_page
          build_sitemap
          build_feed
          build_search
        when %r{\Acss/.+\.(scss|css)\z}
          # css is concatenated before compiling, so a single change recompiles all.
          compile_css
        when 'javascripts/app.js'
          compile_js
        when %r{\Aimages/[^/]+\z}
          copy_image(path) if File.exist?(path)
        else
          config.logger.info "No build strategy for #{relative}, skipping"
        end
      ensure
        reset_posts_metadata
      end

      private

      # Fails the build, before anything is written, when a post's filename
      # is one of RESERVED_POST_NAMES, or the name of a category page this
      # build will write (category-ruby.html), and so would overwrite (or be
      # overwritten by) a page Parrot generates itself.
      def check_reserved_post_names!
        category_pages = posts_by_category.flat_map do |slug, category|
          (1..paginated_posts(category[:posts]).length).map { |number| category_filename(slug, number).delete_suffix('.html') }
        end

        clashes = Dir["#{app_root}/views/posts/*.md"].select do |post_path|
          name = File.basename(post_path, '.md')
          name.match?(RESERVED_POST_NAMES) || category_pages.include?(name.downcase)
        end
        return if clashes.empty?

        names = clashes.map { |post_path| "views/posts/#{File.basename(post_path)}" }.join(', ')
        raise "Reserved post filename: #{names}. index*, 404, about, categories, category, now, post(s), " \
              "note(s) and category page names (category-<name>) can't be used as post names; " \
              'rename the post to build.'
      end

      # The posts this build writes out: every views/posts/*.md, minus drafts
      # under `parrot build` (`serve` builds drafts so they can be previewed).
      # The index listing, sitemap and feed read from this too, so none of
      # them links a page that wasn't built.
      def published_post_paths
        Dir["#{app_root}/views/posts/*.md"].reject do |post_path|
          build_mode? && draft_post?(post_metadata(post_path))
        end
      end

      def build_mode?
        @config[:build_mode]
      end

      # The category listing a post's `category` links to ("category-ruby.html"),
      # or nil when it has none, or one with no letters or digits to name a
      # page after.
      def category_href(meta)
        category = post_category(meta)
        slug = category && Helpers.slugify(category)
        slug.nil? || slug.empty? ? nil : category_filename(slug, 1)
      end

      # "category-ruby.html" for page 1, "category-ruby_2.html", … after that.
      # Slugs never contain "_", so a page number can't be mistaken for part of
      # another category's name ("web3" vs page 3 of "web").
      def category_filename(slug, page_number)
        page_number == 1 ? "category-#{slug}.html" : "category-#{slug}_#{page_number}.html"
      end

      # Every category in use as { slug => { name:, posts: } }, sorted by name,
      # each category's posts newest first. Names that slugify the same ("C++"
      # and "C") share one listing under the first name seen, with a warning;
      # a name with no letters or digits gets no listing at all.
      def posts_by_category
        @posts_by_category ||= begin
          categories = {}

          sorted_posts_metadata.each do |meta|
            name = post_category(meta)
            next unless name

            slug = Helpers.slugify(name)
            if slug.empty?
              config.logger.warn "Category #{name.inspect} in #{meta['__filename']} has no letters or digits, skipping it"
              next
            end

            category = categories[slug] ||= { name: name, posts: [] }
            if category[:name] != name
              config.logger.warn "Category #{name.inspect} in #{meta['__filename']} is listed under #{category[:name].inspect}"
            end
            category[:posts] << meta
          end

          categories.sort_by { |_slug, category| category[:name].downcase }.to_h
        end
      end

      # Sets the per-page <html lang>, <title>, <meta property="og:*"> and
      # <link rel="canonical"> on the built HTML, and turns a relative og:image
      # path into an absolute URL (copying the file into the build). The site's
      # base URL comes from the layout (its canonical/og:url tag); the generated
      # file's path is appended so each page points at itself. `meta` is the
      # post's header Hash (empty for the index). `kind` is :index, :post,
      # :about or :category; only a post gets article metadata.
      def apply_page_meta(html, output_name, meta = {}, kind: index_page?(output_name) ? :index : :post)
        title = meta['title']

        if title && !title.empty?
          title_tag = html.at('head title')
          title_tag.content = title if title_tag
        end

        lang = meta['lang']
        if lang && !lang.empty?
          root = html.at('html')
          root['lang'] = lang if root
        end

        base = canonical_base(html)
        return unless base

        page_url = output_name == 'index.html' ? "#{base}/" : "#{base}/#{output_name}"

        og = html.at('head meta[property="og:url"]')
        og['content'] = page_url if og

        canonical = html.at('head link[rel="canonical"]')
        canonical['href'] = page_url if canonical

        page_title = html.at('head title')&.text
        og_title = html.at('head meta[property="og:title"]')
        og_title['content'] = page_title if og_title && page_title && !page_title.empty?

        apply_description(html, meta['description'])
        apply_locale(html, meta['lang'])
        apply_article_meta(html, meta) if kind == :post

        resolve_og_image(html, base)

        feed = html.at('head link[rel="alternate"][type="application/rss+xml"]')
        feed['href'] = "#{base}/feed.xml" if feed && !feed['href'].to_s.start_with?('http')

        inject_json_ld(html, kind, meta, page_url)
      end

      # Fills <meta name="description">, og:description and twitter:description
      # from one string (the post header's `description` or its first paragraph).
      def apply_description(html, description)
        return if description.nil? || description.empty?

        ['meta[name="description"]',
         'meta[property="og:description"]',
         'meta[name="twitter:description"]'].each do |selector|
          node = html.at("head #{selector}")
          node['content'] = description if node
        end
      end

      # Maps the page's `lang` onto og:locale (en -> en_US, ml -> ml_IN, …).
      def apply_locale(html, lang)
        node = html.at('head meta[property="og:locale"]')
        return unless node && lang && !lang.empty?

        locales = { 'en' => 'en_US', 'ml' => 'ml_IN', 'hi' => 'hi_IN', 'ta' => 'ta_IN' }
        node['content'] = locales.fetch(lang, lang)
      end

      # Adds a schema.org JSON-LD block: BlogPosting for a post, AboutPage for
      # the about page, WebSite for the index. Values are read back from the
      # <head> this method has just filled.
      def inject_json_ld(html, kind, meta, page_url)
        site_name = meta_content(html, 'meta[property="og:site_name"]')
        description = meta_content(html, 'meta[name="description"]')

        data = {
          '@context' => 'https://schema.org',
          '@type' => { post: 'BlogPosting', about: 'AboutPage', category: 'CollectionPage', index: 'WebSite' }.fetch(kind),
          'url' => page_url
        }

        case kind
        when :post
          data['headline'] = html.at('head title')&.text || meta['title']
          data['mainEntityOfPage'] = page_url
          data['inLanguage'] = meta['lang'] || 'en'
          if (published = iso_date(meta['date']))
            data['datePublished'] = published
            data['dateModified'] = published
          end
          data['description'] = description if description
          tags = post_tags(meta)
          data['keywords'] = tags.join(', ') unless tags.empty?
          image = meta_content(html, 'meta[property="og:image"]')
          data['image'] = image if image&.start_with?('http')
          author = meta_content(html, 'meta[name="author"]')
          data['author'] = { '@type' => 'Person', 'name' => author } if author
          data['publisher'] = { '@type' => 'Organization', 'name' => site_name } if site_name
        when :about, :category
          data['name'] = html.at('head title')&.text
          data['description'] = description if description
        else
          data['name'] = site_name || html.at('head title')&.text
          data['description'] = description if description
        end

        json = JSON.pretty_generate(data).gsub('</', '<\\/')
        (html.at('head') || html).add_child(%(<script type="application/ld+json">#{json}</script>))
      end

      # A description drawn from the post body: the first paragraph with at least
      # `minimum` characters (so a date byline or a "write your post here" stub
      # is skipped), whitespace-collapsed and trimmed to ~155 characters on a
      # word boundary. nil when nothing qualifies.
      def summarize(fragment, limit = 155, minimum = 40)
        para = Nokogiri::HTML(fragment.to_s)
                       .css('p')
                       .map { |node| node.text.gsub(/\s+/, ' ').strip }
                       .find { |text| text.length >= minimum }
        return unless para
        return para if para.length <= limit

        "#{para[0, limit].sub(/\s+\S*\z/, '').rstrip}…"
      end

      def meta_content(html, selector)
        value = html.at("head #{selector}")&.[]('content')
        value unless value.nil? || value.empty?
      end

      # A post is an OG "article", not a "website"; add its publish date (from
      # the header's dd/mm/yyyy `date`) as article:published_time in ISO form.
      def apply_article_meta(html, meta)
        og_type = html.at('head meta[property="og:type"]')
        og_type['content'] = 'article' if og_type

        post_tags(meta).each do |tag|
          node = Nokogiri::XML::Node.new('meta', html)
          node['property'] = 'article:tag'
          node['content'] = tag
          (html.at('head') || html).add_child(node)
        end

        published = iso_date(meta['date'])
        return unless published

        node = Nokogiri::XML::Node.new('meta', html)
        node['property'] = 'article:published_time'
        node['content'] = published
        (html.at('head') || html).add_child(node)
      end

      # "31/12/2026" -> Date.new(2026, 12, 31); nil for a blank or invalid value.
      def parse_post_date(value)
        day, month, year = value.to_s.strip.split('/')
        return unless day && month && year

        Date.new(year.to_i, month.to_i, day.to_i)
      rescue ArgumentError
        nil
      end

      # "31/12/2026" -> "2026-12-31"; nil for a blank or invalid value.
      def iso_date(value)
        parse_post_date(value)&.iso8601
      end

      # "31/12/2026" -> "Thu, 31 Dec 2026 00:00:00 -0000" for RSS <pubDate>.
      def rfc822_date(value)
        date = parse_post_date(value)
        return unless date

        Time.utc(date.year, date.month, date.day).rfc2822
      end

      # Open Graph and Twitter require an absolute og:image URL. Rewrite a
      # relative images/… path against the site's base URL and copy the file
      # into the build; leave an already-absolute URL untouched. When the source
      # is local, also emit og:image:width/height so scrapers can lay the card
      # out without fetching the file first.
      def resolve_og_image(html, base)
        og_image = html.at('head meta[property="og:image"]')
        src = og_image && og_image['content']
        return if src.nil? || src.empty? || src.start_with?('http://', 'https://', '//')

        source_path = File.join(app_root, src)
        if src.start_with?('images/') && File.exist?(source_path)
          copy_image(source_path)

          if (dimensions = image_dimensions(source_path))
            set_head_meta(html, 'og:image:width', dimensions[0].to_s)
            set_head_meta(html, 'og:image:height', dimensions[1].to_s)
          end
        end

        og_image['content'] = "#{base}/#{src}"
      end

      # Sets <meta property="…">, adding the tag to <head> if it isn't there.
      def set_head_meta(html, property, content)
        node = html.at(%(head meta[property="#{property}"]))
        unless node
          node = Nokogiri::XML::Node.new('meta', html)
          node['property'] = property
          (html.at('head') || html).add_child(node)
        end
        node['content'] = content # rubocop:disable Lint/UselessSetterCall -- node lives in the document
      end

      # [width, height] of a PNG, JPEG or GIF, read from the file header only.
      # nil for anything else or an unreadable file.
      def image_dimensions(path)
        File.open(path, 'rb') do |io|
          head = io.read(24) or return nil

          if head.byteslice(0, 8) == "\x89PNG\r\n\x1a\n".b
            head.byteslice(16, 8).unpack('N2')
          elsif head.byteslice(0, 3) == 'GIF'.b
            head.byteslice(6, 4).unpack('v2')
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
          next if marker == 0x01 || marker.between?(0xD0, 0xD9)

          length = io.read(2)&.unpack1('n')
          return nil if length.nil?

          if marker.between?(0xC0, 0xCF) && ![0xC4, 0xC8, 0xCC].include?(marker)
            frame = io.read(5) or return nil
            height, width = frame.byteslice(1, 4).unpack('n2')
            return [width, height]
          end

          io.seek(length - 2, IO::SEEK_CUR)
        end
      end

      # The site's base URL as declared in the layout, without a trailing slash.
      def canonical_base(html)
        node = html.at('head link[rel="canonical"]') || html.at('head meta[property="og:url"]')
        value = node && (node['href'] || node['content'])
        value&.strip&.chomp('/')
      end

      # Same base URL, read straight from the rendered layout — for build steps
      # (sitemap, robots) that aren't tied to one page.
      def site_base_url
        layout = Tilt.new("#{app_root}/views/layout.html.erb")
        canonical_base(Nokogiri::HTML(layout.render { '' }))
      end

      def xml_escape(text)
        text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
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
          theme.render(scope: '.highlighter-rouge'),
          '.highlighter-rouge{margin:1rem 0;padding:1rem;overflow-x:auto;border-radius:6px}',
          '.highlighter-rouge pre,.highlighter-rouge code{margin:0;padding:0;background:none;border:0}'
        ].join("\n")
      end

      def markdown(file)
        markdown_string(File.read(file))
      end

      # Same rendering as #markdown, for content that isn't backed by a file
      # (the generated post listing on the index page).
      def markdown_string(content)
        # GFM so ```lang fences work; rouge tags every token in a fenced code
        # block with a class, which #syntax_highlight_css then colours.
        Tilt::KramdownTemplate.new(
          input: 'GFM',
          hard_wrap: false,
          syntax_highlighter: 'rouge',
          syntax_highlighter_opts: { formatter: CodeFormatter },
          math_engine: 'mathjax',
          math_engine_opts: { format: [:html] },
          auto_ids: false
        ) { content }
      end

      # One index page's Markdown body: a heading (config.yaml's
      # post_listing.list_title, page 1 only, omitted entirely when
      # explicitly set to an empty string) followed by that page's slice of
      # the post listing and, when there's more than one page, a pager —
      # generated from views/posts/*.md, there is no views/index.md.
      def index_markdown(page_number, posts_meta, total_pages)
        heading = page_number == 1 ? list_title_heading : ''
        markdown = "#{heading}#{render_post_listing(posts_meta)}\n"

        pager = pager_markdown(page_number, total_pages)
        markdown << "\n#{pager}\n" unless pager.empty?

        markdown
      end

      # "index.html" for page 1, "index2.html", "index3.html", … after that.
      def index_filename(page_number)
        page_number == 1 ? 'index.html' : "index#{page_number}.html"
      end

      def index_page?(output_name)
        output_name.match?(/\Aindex\d*\.html\z/)
      end

      # config.yaml's post_listing.per_page as an Integer, or nil when unset
      # (or not a positive number) — meaning "don't paginate".
      def per_page_setting
        value = post_listing_settings['per_page'].to_i
        value.positive? ? value : nil
      end

      # Splits already-sorted (newest-first) post metadata into per_page-sized
      # pages. A single page (even an empty one) when per_page isn't set or
      # there aren't enough posts to need a second page — same as Parrot's
      # single-index-page behaviour before pagination existed.
      def paginated_posts(posts_meta)
        size = per_page_setting
        return [posts_meta] if size.nil? || posts_meta.length <= size

        posts_meta.each_slice(size).to_a
      end

      # Maps each post's filename to the index page number it appears on, so
      # every post's back-link can point at the right page.
      def page_number_lookup(posts_meta)
        lookup = {}
        paginated_posts(posts_meta).each_with_index do |chunk, index|
          chunk.each { |meta| lookup[meta['__filename']] = index + 1 }
        end
        lookup
      end

      # A "← Newer posts" / "Older posts →" markdown line for one index page,
      # linking to the adjacent page(s); "" when there's nothing to link to
      # (a single-page site, or the newer/older side is explicitly disabled
      # via an empty post_listing.newer_link_text/older_link_text).
      # `filename` maps a page number to its file: index pages by default,
      # category pages pass their own.
      def pager_markdown(page_number, total_pages, filename = method(:index_filename))
        settings = post_listing_settings
        newer_text = settings.fetch('newer_link_text', DEFAULT_NEWER_LINK_TEXT)
        older_text = settings.fetch('older_link_text', DEFAULT_OLDER_LINK_TEXT)

        links = []
        links << "[#{newer_text}](#{filename.call(page_number - 1)})" if page_number > 1 && !newer_text.to_s.empty?
        links << "[#{older_text}](#{filename.call(page_number + 1)})" if page_number < total_pages && !older_text.to_s.empty?
        return '' if links.empty?

        "#{links.join(' ~ ')}\n{: .pagination}"
      end

      # Deletes any previously-built index page beyond the current page
      # count, so a shrinking post count doesn't leave a stale index3.html
      # behind after a rebuild drops it to 2 pages.
      def cleanup_stale_index_pages(total_pages)
        Dir[File.join(build_path, 'index*.html')].each do |path|
          match = File.basename(path).match(/\Aindex(\d*)\.html\z/)
          next unless match

          page_number = match[1].empty? ? 1 : match[1].to_i
          File.delete(path) if page_number > total_pages
        end
      end

      def list_title_heading
        settings = post_listing_settings
        return '' if settings.key?('list_title') && settings['list_title'].to_s.strip.empty?

        "### #{settings['list_title'] || DEFAULT_LIST_TITLE}\n\n"
      end

      # Every post's header metadata plus its parsed date and source filename,
      # newest first. Undated posts (or posts with an unparsable date) sort last.
      # Only headers are read, never post bodies. The index, category pages
      # and sitemap all list from this, so it's read once per #run or #build
      # and reused (see #reset_posts_metadata).
      def sorted_posts_metadata
        @sorted_posts_metadata ||= begin
          posts_meta = published_post_paths.map do |post_path|
            meta = post_metadata(post_path)
            meta.merge(
              '__filename' => File.basename(post_path),
              '__date' => parse_post_date(meta['date'])
            )
          end
          posts_meta.sort_by { |meta| meta['__date'] || Date.new(0) }.reverse
        end
      end

      # Forgets the posts read by #sorted_posts_metadata, at the start and end
      # of every #run and #build, so the watcher always sees the latest edits.
      def reset_posts_metadata
        @sorted_posts_metadata = nil
        @posts_by_category = nil
      end

      # Renders the Markdown post listing per config.yaml's
      # post_listing settings (list_format, and group_by: year/month/none).
      def render_post_listing(posts_meta)
        settings = post_listing_settings
        format = settings['list_format'] || DEFAULT_LIST_FORMAT
        group_by = settings['group_by'] || DEFAULT_GROUP_BY

        case group_by
        when 'year'
          grouped_listing(posts_meta, format) { |date| date.strftime('%Y') }
        when 'month'
          grouped_listing(posts_meta, format) { |date| date.strftime('%B %Y') }
        else
          flat_listing(posts_meta, format)
        end
      end

      def flat_listing(posts_meta, format)
        posts_meta.map { |meta| "- #{format_list_entry(format, meta)}" }.join("\n")
      end

      # Splits the (already newest-first) posts into labelled sections, in the
      # order their label was first seen, so sections stay newest-first too.
      def grouped_listing(posts_meta, format)
        posts_meta
          .group_by { |meta| meta['__date'] ? yield(meta['__date']) : 'Undated' }
          .map { |label, entries| "## #{label}\n\n#{flat_listing(entries, format)}" }
          .join("\n\n")
      end

      # Expands a list_format string like
      # "{post_date} ~ [{post_title}]({post_link})" against one post's
      # metadata. `{post_<key>}` is that key read straight from the post's
      # `<!-- key: value -->` header, as plain text (so `{post_title}`,
      # `{post_lang}`, or any custom header field); `{post_date}` is the same
      # header field but formatted per post_date_format.on_list, and
      # `{post_link}` is the one field Parrot computes itself — the post's
      # href, rewritten to the built page by #update_internal_links. Wrap
      # whichever one should be clickable in Markdown link syntax yourself.
      # Any other `{...}` is a strftime format string (see Date#strftime)
      # applied to the post's header `date`.
      def format_list_entry(format, meta)
        format.gsub(/\{([^}]*)\}/) do
          token = ::Regexp.last_match(1)
          if token == 'post_link'
            "##{meta['__filename']}"
          elsif token == 'post_category_tag'
            category_tag_markdown(meta)
          elsif token == 'post_date'
            meta['__date']&.strftime(post_date_format('on_list')) || ''
          elsif token.start_with?('post_')
            meta[token.sub(/\Apost_/, '')].to_s
          else
            meta['__date']&.strftime(token) || ''
          end
        end
      end

      # `{post_category_tag}` in a list_format: the post's category as a link to
      # its listing, given the same `category-tag` class as the one under a
      # post's title; "" for a post without a category.
      def category_tag_markdown(meta)
        href = category_href(meta)
        return '' unless href

        "[#{escape_markdown(post_category(meta))}](#{href}){: .category-tag}"
      end

      # Backslash-escapes the characters kramdown would otherwise read as
      # markup, for header text (a category name) dropped into Markdown.
      def escape_markdown(text)
        text.gsub(/([\\`*_{}\[\]()#+\-.!|<>])/) { "\\#{::Regexp.last_match(1)}" }
      end

      # Expands a literal "{post_title}" placeholder inside a post's own
      def substitute_post_title(content, meta)
        return content if meta['title'].nil?

        content.gsub('{post_title}', meta['title'])
      end

      # Expands a literal "{post_date}" placeholder inside a post's own
      # Markdown body (as opposed to a post_listing list_format), formatted
      # per post_date_format.on_post.
      def substitute_post_date(content, meta)
        return content unless meta['__date']

        content.gsub('{post_date}') { meta['__date'].strftime(post_date_format('on_post')) }
      end

      # The `on_list` or `on_post` pattern from config.yaml's
      # `post_date_format` section, falling back to DEFAULT_POST_DATE_FORMAT.
      def post_date_format(context)
        post_date_format_settings[context] || DEFAULT_POST_DATE_FORMAT.fetch(context)
      end

      # The `post_listing` section of config.yaml, or {} when the
      # file is missing or invalid.
      def post_listing_settings
        posts_config['post_listing'] || {}
      end

      # The `search` section of config.yaml, or {}.
      def search_settings
        settings = posts_config['search']
        settings.is_a?(Hash) ? settings : {}
      end

      # Search is on unless config.yaml sets search.enabled to false.
      def search_enabled?
        search_settings['enabled'] != false
      end

      # The `post_date_format` section of config.yaml, or {}.
      def post_date_format_settings
        posts_config['post_date_format'] || {}
      end

      def posts_config
        path = File.join(app_root, 'config.yaml')
        return {} unless File.exist?(path)

        YAML.safe_load_file(path) || {}
      rescue Psych::SyntaxError => e
        config.logger.info "Invalid config.yaml, using defaults: #{e.message}"
        {}
      end
    end
  end
end
