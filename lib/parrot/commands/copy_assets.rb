require 'fileutils'
require_relative '../skeleton'
require_relative '../menu'
require_relative '../copy_code'
require_relative '../search/searchable'

module Parrot
  module Commands
    # Copies into a blog the skeleton's styles and icons it's missing, so a
    # blog created by an older Parrot can edit them like the rest of the
    # blog. Without them the build falls back to the skeleton's copies, so
    # nothing breaks either way. Scripts aren't copied: the gem ships those
    # into every build. Never overwrites a file the blog already has. Runs
    # from the blog's root.
    # @usage parrot copy-assets
    class CopyAssetsCommand
      FILES = [
        Search::Searchable::SEARCH_STYLESHEET,
        CopyCode::COPY_CODE_STYLESHEET,
        Menu::MENU_STYLESHEET,
        CopyCode::COPY_ICON,
        File.join('images', 'favicon.ico'),
        File.join('images', 'favicon.svg'),
        File.join('images', 'apple-touch-icon.png')
      ].freeze

      attr_reader :config, :app_root

      def initialize(_args = [], config)
        @config = config
        @app_root = @config&.root_dir
        raise ArgumentError if @app_root.nil?
      end

      def run
        raise "Run this from the blog's root (no views/layout.html.erb found)" unless File.exist?(File.join(app_root, 'views', 'layout.html.erb'))

        missing = FILES.reject { |file| File.exist?(File.join(app_root, file)) }
        missing.each do |file|
          FileUtils.mkdir_p(File.dirname(File.join(app_root, file)))
          FileUtils.cp(File.join(Skeleton::DIR, file), File.join(app_root, file))
          puts "Copied #{file}"
        end
        puts 'Nothing to copy, the blog has every asset.' if missing.empty?
      end
    end
  end
end
