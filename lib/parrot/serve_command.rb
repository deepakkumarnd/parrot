require 'webrick'
require 'parrot/template_handler'
require 'pp'
require 'watchr'

module Parrot
  module Commands
    class ServeCommand
      def initialize(args=[])
        @args = args
      end

      def run
        Thread.new do
          puts 'Watching app'
          watch_app
        end

        run_server
      end

      private

      def run_server
        server = WEBrick::HTTPServer.new :Port => 8000, :DocumentRoot => "#{Parrot::Root}/build"

        trap 'INT' do
          server.shutdown
        end

        server.start
      end

      def watch_app
        ENV['HANDLER'] = `uname`.strip
        watcher = Watchr::Script.new
        all_files = Dir.glob("**/*").select { |item| File.file?(item) && !item.start_with?("build/")}.join('|')
        script = Watchr::Script.new

        script.watch(all_files) do |file|
          puts "File changed #{file}"
          BuildCommand.new.run
        end

        controller = Watchr::Controller.new(script, Watchr.handler.new)
        controller.run
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
        pp path
      end
    end
  end
end