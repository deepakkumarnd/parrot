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
      CHECKSUM_FILE = '.checksum'.freeze

      # Serves the build directory like WEBrick's FileHandler, but answers a
      # missing path with the built 404.html (still with a 404 status), the
      # way static hosts do, instead of WEBrick's generic error page.
      class FileHandler < WEBrick::HTTPServlet::FileHandler
        def initialize(server, root, options = {}, default = WEBrick::Config::FileHandler)
          super
          @not_found_page = File.join(root, '404.html')
        end

        def service(req, res)
          super
        rescue WEBrick::HTTPStatus::NotFound
          raise unless File.file?(@not_found_page)

          res.status = 404
          res['Content-Type'] = 'text/html; charset=utf-8'
          res.body = File.read(@not_found_page)
        end
      end

      attr_reader :config, :document_root, :app_root

      def initialize(args = [], config)
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
        server = WEBrick::HTTPServer.new Port: @port
        server.mount('/', FileHandler, @document_root)

        trap 'INT' do
          server.shutdown
        end

        server.start
      end

      def watch_app
        ENV['HANDLER'] = `uname`.strip
        watcher = Watchr::Script.new
        all_files = Dir.glob('**/*').select { |item| File.file?(item) && !item.start_with?('public/') }
        @cache = FileCache.instance
        builder = BuildCommand.new([], config)
        builder.unset_build_mode!

        all_files.each do |file|
          absolute_path = File.join(app_root, file)
          @cache.set(absolute_path)
        end

        build_if_stale(builder, @cache.checksum)

        watcher.watch(all_files.join('|')) do |file|
          config.logger.info "File changed #{file}"
          path = "#{app_root}/#{file}"

          if @cache.changed? path
            @cache.set(path)
            builder.build(file)
          end
        end

        controller = Watchr::Controller.new(watcher, Watchr.handler.new)
        controller.run
      rescue Exception => e # rubocop:disable Lint/RescueException -- also log Ctrl-C/exit from the watcher loop
        config.logger.error("#{e.message}\n#{e.backtrace.join("\n")}")
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
          config.logger.info 'No source changes since last build, skipping full build'
          return
        end

        builder.run
        File.write(checksum_path, checksum)
        config.logger.info "Wrote build checksum to #{checksum_path}"
      end

      def handle_path(path)
        path.chop! while path[-1] == '/'

        path = '/index.html' if path == ''

        template_type = path.split('.').last.to_sym
        handler = TemplateHandler.new(root: document_root, path: path, handle: template_type)
        handler.compile
      end
    end
  end
end
