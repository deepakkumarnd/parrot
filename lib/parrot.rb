require 'optparse'

require_relative 'parrot/version'
require_relative 'parrot/runner'
require_relative 'parrot/logger'
require_relative 'parrot/constants'

module Parrot

  Config = Struct.new(:root_dir, :logger)
  class Parrot
    SUB_COMMANDS = %w( new build serve post )

    attr_accessor :root_dir, :logger, :config
    def initialize(args = [])
      @options = { quiet: false }
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

    def self.usage
      "Usage: parrot <#{SUB_COMMANDS.join('|')}> options"
    end

    def exit_if_invalid(command)
      if command.nil? || !SUB_COMMANDS.include?(command)
        puts(Parrot.usage)
        exit!
      end
    end

    def quiet?
      @options[:quiet]
    end

    private

    def extract_options!(args)
      OptionParser.new do |opts|
        opts.on('-q', '--quiet', 'Quiet mode') { @options[:quiet] = true }
        opts.on_tail('-v', '--version', 'Prints version information') do
          puts("Parrot #{VERSION}")
          exit(0)
        end
        opts.on_tail('-h', '--help', 'Usage instructions') do
          puts(Parrot.usage)
          puts(
            """
            Create a new blog

            $ parrot new blog

            Start the server

            $ cd blog
            $ parrot serve

            Add a new post

            $ parrot post --title \"My first post\"

            Build the blog

            $ parrot build
            """)
          exit(0)
        end
      end.order!(args)
      # Stop at the first non-option (the sub-command) so flags that belong to
      # the sub-command, e.g. `parrot post --title "..."`, are left untouched.
    end
  end
end