require 'fileutils'
require 'pry'
require 'parrot/watch_command'

module Parrot
  module Commands
    class NewCommand
      def initialize(args=[])
        @app_root = args.first
        raise ArgumentError if @app_root.nil?
      end

      def run
        puts "Creating new application #{@app_root}"
        puts "Using skel from #{File.expand_path('../skel', __FILE__)}"
        FileUtils.cp_r(File.expand_path('../../../skel', __FILE__), @app_root)
        FileUtils.mkpath(@app_root)
      end
    end

    class BuildCommand
      def initialize(args=[])
        @args = args
      end

      def run
        puts "Building application at #{Parrot::Root}"
        FileUtils.rm_rf('build')
        FileUtils.mkdir('build')
      end
    end
  end

  class Builder

    include Commands

    attr_reader :klass

    def initialize(command, args=[])
      @klass = to_command_class(command)
      @klass.new(args).run
    end

    private

    def to_command_class(command)
      Commands.const_get("#{command.capitalize}Command")
    end
  end
end
