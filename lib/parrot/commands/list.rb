require_relative '../post_header'

module Parrot
  module Commands
    # Shared by `list-tags` and `list-categories`: prints every name in use
    # across views/posts with how many posts use it, one per line, sorted by
    # name. Drafts are counted too, since this is for the author, not readers.
    # Names are listed exactly as written, so "Ruby" and "ruby" show up
    # separately and the inconsistency is easy to spot.
    # Runs from the blog's root, like `build` and `serve`.
    class ListCommand
      include PostHeader

      attr_reader :config, :app_root

      def initialize(_args = [], config)
        @config = config
        @app_root = @config&.root_dir
        raise ArgumentError if @app_root.nil?
      end

      def run
        posts_dir = File.join(app_root, 'views', 'posts')
        raise "Run this from the blog's root (no views/posts found)" unless Dir.exist?(posts_dir)

        counts = Dir["#{posts_dir}/*.md"].each_with_object(Hash.new(0)) do |post_path, counts|
          names(post_metadata(post_path)).each { |name| counts[name] += 1 }
        end

        if counts.empty?
          puts "No #{plural} yet."
        else
          counts.sort_by { |name, _count| [name.downcase, name] }.each { |name, count| puts "#{name} (#{count})" }
        end
      end
    end

    # @usage parrot list-tags
    class ListTagsCommand < ListCommand
      private

      def names(meta)
        post_tags(meta)
      end

      def plural
        'tags'
      end
    end

    # @usage parrot list-categories
    class ListCategoriesCommand < ListCommand
      private

      def names(meta)
        Array(post_category(meta))
      end

      def plural
        'categories'
      end
    end
  end
end
