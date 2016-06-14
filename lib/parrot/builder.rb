require 'fileutils'
require 'pry'
require 'parrot/serve_command'

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

        FileUtils.cp('favicon.ico', "build/favicon.ico")

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

        # compile js files using babel

        js_files = html.css('script').map do |js|
          js['src'] if js['type'] == "text/javascript"
        end.compact.uniq

        if js_files.count > 0
          FileUtils.mkdir("build/js")
        end

        js_files.each do |js_file|
          if js_file.start_with?('/')
            js_file = js_file[1..-1]
          end

          file_name = File.basename(js_file)
          file_name = file_name.split('.').first
          system("babel #{js_file} --out-file build/js/#{file_name}.js")
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
