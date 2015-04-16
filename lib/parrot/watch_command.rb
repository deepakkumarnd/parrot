require 'webrick'
require 'parrot/template_handler'
require 'pp'

module Parrot
  module Commands
    class WatchCommand
      def initialize(args=[])
        @args = args
      end

      def run
        run_server
        puts 'watching application at'
      end

      private

      def run_server
        server = WEBrick::HTTPServer.new :Port => 8000, :DocumentRoot => "#{Parrot::Root}/public"
        trap 'INT' do
          server.shutdown
        end

        server.mount_proc '/' do |req, res|
          res.body = handle_path(req.path)
        end

        server.start
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