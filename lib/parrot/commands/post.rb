require 'date'
require 'optparse'

module Parrot

  module Commands

    # Post command scaffolds a new Markdown post and links it from the index page.
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
        index_path = File.join(app_root, "views", "index.md")

        unless Dir.exist?(posts_dir) && File.exist?(index_path)
          raise "Run this from the blog's root (no views/posts or views/index.md found)"
        end

        post_path = File.join(posts_dir, "#{slug}.md")
        raise "Post #{post_path} already exists" if File.exist?(post_path)

        date = Date.today.to_s

        File.write(post_path, post_template(date, Date.today.strftime("%d/%m/%Y")))
        config.logger.info "Created #{post_path}"

        prepend_to_index(index_path, date)
        config.logger.info "Linked #{slug}.md from #{index_path}"
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

      def post_template(date, header_date)
        <<~MARKDOWN
          <!--
          title: #{title}
          date: #{header_date}
          -->

          # #{title}

          _#{date}_

          Write your post here.
        MARKDOWN
      end

      # Insert the new post above the existing ones: before the first list item,
      # or, if the index has none yet, after its last non-empty line.
      def prepend_to_index(index_path, date)
        entry = "- [#{title}](##{slug}.md) — #{date}"
        lines = File.read(index_path).lines.map(&:chomp)

        insert_at = lines.index { |line| line.lstrip.start_with?("- ") }
        insert_at ||= (lines.rindex { |line| !line.strip.empty? } || -1) + 1

        lines.insert(insert_at, entry)
        File.write(index_path, lines.join("\n") + "\n")
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
