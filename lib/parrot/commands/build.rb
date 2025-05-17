require 'pygments'
require 'redcarpet'
require 'tilt'
require 'slim'
require 'nokogiri'

module Parrot

  module Commands

    # Build command builds the HTML static app
    # @usage  parrot build
    # The build files will be kept in the build directory
    class BuildCommand

      attr_accessor :html, :app_root, :config

      def initialize(args=[], config)
        @config = config
        @args = args
        @app_root = @config.root_dir
      end

      def build_index_page
        layout = Tilt.new("#{app_root}/views/layout.html.erb")

        text = layout.render do
          index = Tilt.new("#{app_root}/views/index.md")
          index.render
        end

        f = File.open("#{app_root}/public/index.html", 'w+')
        f.write(text)
        f.close

        self.html = Nokogiri::HTML(text)
      end

      def copy_image_assets
        images = html.css('link').map do |ln|
          ln['href'] if ln['type'] =~ /\Aimage/
        end.compact.uniq

        images.each do |img|
          if img.start_with?('/')
            img = img[1..-1]
          end

          FileUtils.cp(img, "#{app_root}/public/#{img}")
        end

        if Dir.exist? 'images'
          FileUtils.cp_r('images', "build/images")
        end
      end

      def compile_css
        css = html.css('link').map do |ln|
          ln['href'] if ln['type'] == 'text/css'
        end.compact.uniq

        css.each do |css_file|
          if css_file.start_with?('/')
            css_file = css_file[1..-1]
          end

          file_name = File.basename(css_file)
          file_name = file_name.split('.').first

          if File.exist? css_file
            FileUtils.cp css_file, "#{app_root}/public/#{file_name}.css"
          else
            css_file = css_file.sub('.css', '.scss')
            system("scss #{css_file} > build/css/#{file_name}.css")
          end
        end
      end

      def compile_js
        js_files = html.css('script').map do |js|
          js['src'] if js['type'] == 'text/javascripts'
        end.compact.uniq

        if js_files.count > 0
          FileUtils.mkdir('build/javascripts')
        end

        js_files.each do |js_file|
          if js_file.start_with?('/')
            js_file = js_file[1..-1]
          end

          file_name = File.basename(js_file)
          file_name = file_name.split('.').first
          system("babel #{js_file} --out-file build/javascripts/#{file_name}.javascripts")
        end
      end

      def markdown
        @markdown ||= Redcarpet::Markdown.new(HTMLWithPygments, fenced_code_blocks: true)
      end

      def compile_posts
        posts = Dir.entries('posts')

        posts.delete('.')
        posts.delete('..')


        if posts.count > 0
          FileUtils.mkdir('build/posts')
        end

        posts.each do |post|
          md_text = File.read("posts/#{post}")
          md_text = md_text.split('{% include JB/setup %}').last
          html = markdown.render(md_text)

          f = File.open("build/posts/#{post.sub('.md', '.html')}", 'w')

          post_section = @html.create_element 'div'
          post_section.inner_html = html
          post_section.set_attribute :class, 'page-content'
          @html.css('.page-content')[0].replace(post_section)
          f.write(@html.to_s)
          f.close
        end
      end

      def run
        config.logger.info "Building application at #{app_root}"
        FileUtils.rm_rf('public')
        FileUtils.mkdir('public')
        build_index_page
        # copy_image_assets
        # compile_css
        # compile_js
        # compile_posts
      end
    end
  end
end