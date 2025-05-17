require 'tilt'
require 'nokogiri'
require 'sassc'

module Parrot

  module Commands

    # Build command builds the HTML static app
    # @usage  parrot build
    # The build files will be kept in the build directory
    class BuildCommand

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
            post = Tilt.new(post_path)
            post.render
          end

          html = update_internal_links(text)
          copy_image_assets(html)

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
        css_files = Dir[File.join(File.join(app_root, "css"), '**', '*.{scss,css}')]
        combined_scss = css_files.map { |file| File.read(file) }.join("\n")

        begin
          engine = SassC::Engine.new(
            combined_scss,
            style: :compressed,
            syntax: :scss
          )

          compiled_css = engine.render

          # Write to output file
          target_path = File.join(build_path, "app.css")
          File.write(File.join(build_path, "app.css"), compiled_css)
          config.logger.info "Compiled and minified CSS written to #{target_path}"
        rescue SassC::SyntaxError => e
          puts "SassC Compilation Error: #{e.message}"
        end
      end

      def compile_js
        FileUtils.cp(File.join(app_root, "javascripts", "app.js"), File.join(build_path))
        config.logger.info "Copied app.js to #{build_path}"
      end

      # def markdown
      #   @markdown ||= Redcarpet::Markdown.new(HTMLWithPygments, fenced_code_blocks: true)
      # end

      def run
        config.logger.info "Building application at #{app_root}"
        FileUtils.rm_rf('public')
        FileUtils.mkdir('public')
        build_index_page
        build_posts
        compile_css
        compile_js
      end
    end
  end
end