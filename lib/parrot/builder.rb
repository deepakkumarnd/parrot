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

        if File.exists? @app_root
          raise "Directory #{@app_root} already exists"
        end

        FileUtils.cp_r(File.expand_path('../../../skel', __FILE__), @app_root)
        system("cd #{@app_root}; tree")
      end
    end

    class BuildCommand

      require 'tilt'
      require 'nokogiri'

      def initialize(args=[])
        @args = args
      end

      def run
        puts "Building application at #{Parrot::Root}"
        FileUtils.rm_rf('build')
        FileUtils.mkdir('build')

        # build index page
        t = Tilt.new('index.slim')
        text = t.render
        f = File.open("build/index.html", "w+")
        f.write(text)
        f.close

        # build html page
        html = Nokogiri::HTML(text)

        # copy image resources
        images = html.css('link').map do |ln|
          ln['href'] if ln['type'] =~ /\Aimage/
        end.compact.uniq

        images.each do |img|
          if img.start_with?('/')
            img = img[1..-1]
          end

          FileUtils.cp(img, "build/#{img}")
        end

        # compile and copy stylesheets

        css = html.css('link').map do |ln|
          ln['href'] if ln['type'] == 'text/css'
        end.compact.uniq

        if css.count > 0
          FileUtils.mkdir("build/css")
        end

        css.each do |css_file|
          if css_file.start_with?('/')
            css_file = css_file[1..-1]
          end

          css_file.sub!('.css', '.scss')
          file_name = File.basename(css_file)
          file_name = file_name.split('.').first
          system("scss #{css_file} > build/css/#{file_name}.css")
        end
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
