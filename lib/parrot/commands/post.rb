require 'date'
require 'optparse'

module Parrot

  module Commands

    # Post command scaffolds a new Markdown post. The index page's listing is
    # generated at build time from every file in views/posts, so nothing here
    # needs to link it in.
    # @usage parrot post --title "My first post"
    # Runs from the blog's root, like `build` and `serve`.
    class PostCommand

      USAGE = 'Usage: parrot post --title "My new post"'

      attr_reader :config, :app_root, :title, :slug

      def initialize(args = [], config)
        @config = config
        @title = extract_title(Array(args)).strip
        @app_root = @config && @config.root_dir
        raise ArgumentError, USAGE if @title.empty?
        raise ArgumentError if @app_root.nil?
        @slug = slugify(@title)
      end

      def run
        raise ArgumentError, "Title has no letters or digits to build a filename from.\n#{USAGE}" if slug.empty?

        posts_dir = File.join(app_root, "views", "posts")

        unless Dir.exist?(posts_dir)
          raise "Run this from the blog's root (no views/posts found)"
        end

        post_path = File.join(posts_dir, "#{slug}.md")
        raise "Post #{post_path} already exists" if File.exist?(post_path)

        File.write(post_path, post_template(Date.today.strftime("%d/%m/%Y")))
        config.logger.info "Created #{post_path}"
      end

      private

      # The title comes from `--title`. Any words left over after the option are
      # treated as part of the title too, so all of these give "My new post":
      #   parrot post --title "My new post"
      #   parrot post --title 'My new post'
      #   parrot post --title My new post
      def extract_title(args)
        from_option = []
        rest = args.dup

        OptionParser.new do |opts|
          opts.on('--title TITLE', 'Title for the new post') { |t| from_option << t }
        end.parse!(rest)

        (from_option + rest).join(' ')
      rescue OptionParser::ParseError
        raise ArgumentError, USAGE
      end

      # {post_date} is filled in at build time, formatted per
      # config.yaml's post_date_format.on_post.
      def post_template(header_date)
        <<~MARKDOWN
          <!--
          title: #{title}
          date: #{header_date}
          lang: en
          -->

          # #{title}

          _{post_date}_

          Write your post here.
        MARKDOWN
      end

      def slugify(text)
        text.downcase
            .gsub(/[^a-z0-9\s-]/, '')
            .strip
            .gsub(/\s+/, '-')
            .gsub(/-+/, '-')
      end
    end
  end
end
