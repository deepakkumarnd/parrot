require 'webrick'
require 'parrot/template_handler'
require 'pp'
require 'watchr'
require_relative '../file_cache'

module Parrot
  module Commands
    class ServeCommand
      def initialize(args=[], config)
        @config = config
        @args = args
        @document_root = "#{config.root_dir}/public"
        @port = 8000
      end

      def run
        Thread.new do
          puts 'Running watch for changes'
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
        all_files = Dir.glob("**/*").select { |item| File.file?(item) && !item.start_with?("public/")}.join('|')

        @cache = FileCache.instance

        all_files.split('|').each do |file|
          path = "#{Parrot.root}/#{file}"
          @cache.set(path)
        end

        watcher.watch(all_files) do |file|
          puts "File changed #{file}"
          path = "#{Parrot.root}/#{file}"

          if @cache.changed? path
            @cache.set(path)
            BuildCommand.new.run
          end
        end

        controller = Watchr::Controller.new(watcher, Watchr.handler.new)
        controller.run
      rescue Exception => e
        puts "Exception #{e.message}"
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
        handler = TemplateHandler.new(root: Parrot::Root, path: path, handle: template_type)
        handler.compile
      end
    end
  end
end