require 'webrick'
require_relative '../template_handler'
require 'pp'
require 'watchr'
require_relative '../file_cache'
require_relative 'build'

module Parrot
  module Commands
    class ServeCommand

      # Combined checksum of the last successful build, kept inside the build
      # directory. It is regenerated output, so it is gitignored and must be
      # excluded from anything that ships the build directory.
      CHECKSUM_FILE = ".checksum"

      attr_reader :config, :document_root, :app_root
      def initialize(args=[], config)
        @config = config
        @args = args
        @app_root = config.root_dir
        @document_root = "#{app_root}/public"
        @port = 8000
      end

      def run
        Thread.new do
          config.logger.info 'Running watch for changes'
          watch_app
        end

        run_server
      end

      private

      def run_server
        server = WEBrick::HTTPServer.new :Port => @port, :DocumentRoot => @document_root

        trap 'INT' do
          server.shutdown
        end

        server.start
      end

      def watch_app
        ENV['HANDLER'] = `uname`.strip
        watcher = Watchr::Script.new
        all_files = Dir.glob("**/*").select { |item| File.file?(item) && !item.start_with?("public/")}
        @cache = FileCache.instance
        builder = BuildCommand.new([], config)

        all_files.each do |file|
          absolute_path = File.join(app_root, file)
          @cache.set(absolute_path)
        end

        build_if_stale(builder, @cache.checksum)

        watcher.watch(all_files.join("|")) do |file|
          config.logger.info "File changed #{file}"
          path = "#{app_root}/#{file}"

          if @cache.changed? path
            @cache.set(path)
            builder.build(file)
          end
        end

        controller = Watchr::Controller.new(watcher, Watchr.handler.new)
        controller.run
      rescue Exception => e
        config.logger.error(e.backtrace.join("\n"))
        exit(-1)
      end

      # Rebuild the whole blog only when the source tree as a whole has moved
      # since the last build. The given FileCache checksum is compared with the
      # one stored in the build directory; a missing or mismatched file triggers
      # a full build, after which the stored checksum is refreshed.
      def build_if_stale(builder, checksum)
        checksum_path = File.join(document_root, CHECKSUM_FILE)
        stored = File.read(checksum_path).strip if File.exist?(checksum_path)

        if stored == checksum
          config.logger.info "No source changes since last build, skipping full build"
          return
        end

        builder.run
        File.write(checksum_path, checksum)
        config.logger.info "Wrote build checksum to #{checksum_path}"
      end

      def handle_path(path)
        while path[-1] == '/'
          path.chop!
        end

        if path == ''
          path = '/index.html'
        else
          path = path
        end

        template_type = path.split('.').last.to_sym
        handler = TemplateHandler.new(root: document_root, path: path, handle: template_type)
        handler.compile
      end
    end
  end
end