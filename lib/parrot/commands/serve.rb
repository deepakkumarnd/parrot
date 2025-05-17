require 'webrick'
require 'parrot/template_handler'
require 'pp'
require 'watchr'
require_relative '../file_cache'

module Parrot
  module Commands
    class ServeCommand

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

        all_files.each do |file|
          absolute_path = File.join(app_root, file)
          @cache.set(absolute_path)
        end

        watcher.watch(all_files.join("|")) do |file|
          config.logger.info "File changed #{file}"
          path = "#{document_root}/#{file}"

          if @cache.changed? path
            @cache.set(path)
            BuildCommand.new([], config).run
          end
        end

        controller = Watchr::Controller.new(watcher, Watchr.handler.new)
        controller.run
      rescue Exception => e
        config.logger.error(e.backtrace.join("\n"))
        exit(-1)
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