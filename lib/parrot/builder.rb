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
        puts 'creating new application #{@app_root}'
        FileUtils.mkpath(@app_root)
        FileUtils.touch("#{@app_root}/index.slim")
        FileUtils.mkpath("#{@app_root}/js")
        FileUtils.touch("#{@app_root}/js/app.coffee")
        FileUtils.mkpath("#{@app_root}/css")
        FileUtils.touch("#{@app_root}/css/app.scss")
        FileUtils.mkpath("#{@app_root}/images")
      end
    end

    class BuildCommand
      def initialize(args=[])
        @args = args
      end

      def run
        puts "building application at #{Parrot::Root}"
        FileUtils.rm_rf('build')
        FileUtils.mkdir('build')
        binding.pry
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
