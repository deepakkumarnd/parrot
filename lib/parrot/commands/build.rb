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
        File.write(File.join(build_path, "index.html"), html)
      end

      def build_posts
        layout = Tilt.new("#{app_root}/views/layout.html.erb")

        Dir["#{app_root}/views/posts/*.md"].each do |post_path|
          text = layout.render do
            post = markdown(post_path)
            post.render
          end

          html = update_internal_links(text)
          copy_image_assets(html)
          html = inject_scripts(html)

          File.write(File.join(build_path, File.basename(post_path).sub('.md', '.html')), html)
        end
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
        images = html.css("img, link")

        if images.size > 0
          FileUtils.mkdir_p(File.join(build_path, "images"))

          images.each do |img|
            next if img["src"].nil?

            source_path = File.join(app_root, img["src"])

            if img["src"].start_with?("images/") && File.exist?(source_path)
              FileUtils.cp(source_path, File.join(build_path, "images"))
            end
          end
        end
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

      private

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