module Parrot

  module Commands

    # New command is to create a new html app
    # @usage parrot new myblog
    class NewCommand

      def initialize(args=[])
        @app_root = args.first
        raise ArgumentError if @app_root.nil?
      end

      def run
        puts "Creating new application #{@app_root}"
        puts "Using skel from #{File.expand_path('../skel', __FILE__)}"

        if File.exists? @app_root
          raise "Directory #{@app_root} already exists"
        end

        FileUtils.cp_r(File.expand_path('../../../skel', __FILE__), @app_root)

        system("cd #{@app_root}; tree")
      end
    end
  end
end
