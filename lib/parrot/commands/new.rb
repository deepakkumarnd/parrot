module Parrot

  module Commands

    # New command is to create a new html app
    # @usage parrot new myblog
    class NewCommand

      attr_reader :config, :app_root

      def initialize(args=[], config)
        @config = config
        @app_root = args.first
        raise ArgumentError if @app_root.nil? || @config.nil?
      end

      def run
        config.logger.info "Creating new application #{app_root}"
        skeleton_path = File.expand_path('../../../../skel', __FILE__)
        config.logger.info "Using skeleten from #{skeleton_path}"

        if Dir.exist? @app_root
          raise "Directory #{@app_root} already exists"
        end

        config.logger.info "Copying skeleten from #{skeleton_path}"
        FileUtils.cp_r(skeleton_path, @app_root)
      end
    end
  end
end
