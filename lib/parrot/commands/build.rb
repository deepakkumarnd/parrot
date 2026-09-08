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

      def build_post(post_path)
        layout = Tilt.new("#{app_root}/views/layout.html.erb")

        text = layout.render do
          markdown(post_path).render
        end

        html = update_internal_links(text)
        copy_image_assets(html)
        html = inject_scripts(html)

        output_name = File.basename(post_path).sub('.md', '.html')
        apply_page_meta(html, output_name, post_metadata(post_path)["title"])

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
        html.css("img, link").each do |img|
          next if img["src"].nil?

          source_path = File.join(app_root, img["src"])

          if img["src"].start_with?("images/") && File.exist?(source_path)
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
        compile_css
        compile_js
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
          # The layout wraps every page, so everything is rebuilt.
          build_index_page
          build_posts
        when "views/index.md"
          build_index_page
        when %r{\Aviews/posts/[^/]+\.md\z}
          File.exist?(path) ? build_post(path) : remove_built_post(path)
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

      # Sets the per-page <title>, <meta property="og:url"> and
      # <link rel="canonical"> on the built HTML. The site's base URL comes from
      # the layout (its canonical/og:url tag); the generated file's path is
      # appended so each page points at itself.
      def apply_page_meta(html, output_name, title = nil)
        if title && !title.empty?
          title_tag = html.at("head title")
          title_tag.content = title if title_tag
        end

        base = canonical_base(html)
        return unless base

        page_url = output_name == "index.html" ? "#{base}/" : "#{base}/#{output_name}"

        og = html.at('head meta[property="og:url"]')
        og["content"] = page_url if og

        canonical = html.at('head link[rel="canonical"]')
        canonical["href"] = page_url if canonical
      end

      # The site's base URL as declared in the layout, without a trailing slash.
      def canonical_base(html)
        node = html.at('head link[rel="canonical"]') || html.at('head meta[property="og:url"]')
        value = node && (node["href"] || node["content"])
        value && value.strip.chomp("/")
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