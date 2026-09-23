require 'optparse'

require_relative 'parrot/metadata'
require_relative 'parrot/runner'
require_relative 'parrot/logger'
require_relative 'parrot/constants'

module Parrot
  Config = Struct.new(:root_dir, :logger)

  SUB_COMMANDS_DOC = {
    new: "new <blog_name> - Create new blog",
    build: "build - Build the blog",
    serve: "serve - Start development server locally",
    post: "post --title <post title> - Add new post with a title"
  }.freeze
  USAGE_LINE = "parrot [options] [subcommand] [args]"

  HELP_TEXT =
<<HELP_TEXT
Examples:
  - Create new blog
    parrot new blog
  
  - Start development server
    cd blog
    parrot serve

  - Add a new post
    parrot post --title \"My first post\"

  - Build the blog
    parrot build
HELP_TEXT

  HELP_HEADER = 
<<HEADER_TEXT
Usage:\t#{USAGE_LINE}
Repository:\t#{Parrot::HOMEPAGE}
Repository:\t#{Parrot::HOMEPAGE}/blob/master/README.md
Version:\t#{Parrot::VERSION}
HEADER_TEXT

  class Parrot
    SUB_COMMANDS = SUB_COMMANDS_DOC.keys.map(&:to_s).freeze

    attr_accessor :root_dir, :logger, :config

    def initialize(args = [])
      @options = { quiet: testing? || false }
      extract_options!(args)
      @command = args.shift
      @args = args
      @logger = ParrotLoggerBuilder.new(@options[:quiet]).logger
      @root_dir = Dir.pwd
      @config = Config.new(@root_dir, @logger)
    end

    def run
      exit_if_invalid(@command)
      Runner.new(@command, @args, self.config).run_command
    rescue ArgumentError => e
      # A command was called with missing or malformed arguments; show how to
      # call it instead of dumping a backtrace.
      warn(e.message)
      exit(1)
    end

    def exit_if_invalid(command)
      if command.nil? || !SUB_COMMANDS.include?(command)
        puts("That is not a valid command. View detailed help with parrot -h")
        puts USAGE_LINE
        exit!
      end
    end

    def quiet?
      @options[:quiet]
    end

    def usage(parser = nil)
      sub_command_doc = "Sub Commands:\n" + SUB_COMMANDS_DOC.values.join("\n") + "\n"
      line_sep = '-' * 80 + "\n"
      [
        HELP_HEADER, 
        parser,
        sub_command_doc,
        HELP_TEXT
      ].join(line_sep)
    end

    private def testing?
      ENV['PARROT_TESTING'] == "true"
    end

    private def extract_options!(args)
      OptionParser.new("Usage: #{USAGE_LINE}") do |parser|
        parser.on('-q', '--quiet', 'Quiet mode') { @options[:quiet] = true }
        parser.on_tail('-v', '--version', 'Prints version information') do
          puts("Parrot #{VERSION}")
          exit(0)
        end
        parser.on_tail('-h', '--help', 'Usage instructions') do
          puts usage(parser)
          exit(0)
        end
      end.order!(args)
      # Stop at the first non-option (the sub-command) so flags that belong to
      # the sub-command, e.g. `parrot post --title "..."`, are left untouched.
    end
  end
end