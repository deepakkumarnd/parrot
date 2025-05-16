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
        skeleton_path = File.expand_path('../../../../skel', __FILE__)
        puts "Using skeleten from #{skeleton_path}"

        if Dir.exist? @app_root
          raise "Directory #{@app_root} already exists"
        end

        puts "Copying skeleten from #{skeleton_path}"
        FileUtils.cp_r(skeleton_path, @app_root)
      end
    end
  end
end
