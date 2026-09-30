require 'optparse'

require_relative 'helpers'
require_relative 'parrot/metadata'
require_relative 'parrot/runner'
require_relative 'parrot/logger'
require_relative 'parrot/constants'

module Parrot
  Config = Struct.new(:root_dir, :logger, :build_mode)

  SubcommandEntry = Struct.new(:usage, :docstr)

  SUB_COMMANDS_DOC = {
    new: SubcommandEntry.new('new <blog_name>', 'Create new blog'),
    build: SubcommandEntry.new('build', 'Build the blog'),
    serve: SubcommandEntry.new('serve', 'Start development server locally'),
    post: SubcommandEntry.new('post --title <post title>', 'Add new post with a title')
  }.freeze

  USAGE_LINE = 'parrot [options] [subcommand] [args]'.freeze

  HELP_TEXT =
    <<~HELP_TEXT.freeze
      Examples:
        - Create new blog
          parrot new blog
      #{'  '}
        - Start development server
          cd blog
          parrot serve

        - Add a new post
          parrot post --title "My first post"

        - Build the blog
          parrot build
    HELP_TEXT

  HELP_HEADER =
    <<~HEADER_TEXT.freeze
      Version:          #{Parrot::VERSION}
      Usage:            #{USAGE_LINE}
      Repository:       #{Parrot::HOMEPAGE}
      Repository:       #{Parrot::HOMEPAGE}/blob/master/README.md
    HEADER_TEXT

  class Parrot
    SUB_COMMANDS = SUB_COMMANDS_DOC.keys.map(&:to_s).freeze

    attr_accessor :root_dir, :logger, :config

    def initialize(args = [])
      @options = { quiet: Helpers.testing? || false }
      extract_options!(args)
      @command = args.shift
      @args = args
      @logger = ParrotLoggerBuilder.new(@options[:quiet]).logger
      @root_dir = Dir.pwd
      @config = Config.new(@root_dir, @logger)
    end

    def run
      return if @command.nil?

      exit_if_invalid(@command)
      Runner.new(@command, @args, config).run_command
    rescue ArgumentError => e
      # A command was called with missing or malformed arguments; show how to
      # call it instead of dumping a backtrace.
      warn(e.message)
      exit(1)
    end

    def exit_if_invalid(command)
      return if SUB_COMMANDS.include?(command)

      puts('That is not a valid command. View detailed help with parrot -h')
      puts USAGE_LINE
      exit!
    end

    def quiet?
      @options[:quiet]
    end

    def usage(parser = nil)
      max_length = SUB_COMMANDS_DOC.map { |_k, v| v.usage.length }.max + 10
      sub_command_doc = SUB_COMMANDS_DOC.map do |_command, entry|
        entry_text = entry.usage.to_s.ljust(max_length)
        "#{entry_text}#{entry.docstr}"
      end.join("\n")

      sub_command_doc = "Sub Commands:\n#{sub_command_doc}\n"
      line_sep = "#{'-' * 80}\n"
      [
        HELP_HEADER,
        parser,
        sub_command_doc,
        HELP_TEXT
      ].join(line_sep)
    end

    private

    def extract_options!(args)
      OptionParser.new("Usage: #{USAGE_LINE}") do |parser|
        parser.on('-q', '--quiet', 'Quiet mode') { @options[:quiet] = true }
        parser.on_tail('-v', '--version', 'Prints version information') do
          puts("Parrot: #{VERSION}")
        end
        parser.on_tail('-h', '--help', 'Prints usage instruction') do
          puts usage(parser)
        end
      end.order!(args)
      # Stop at the first non-option (the sub-command) so flags that belong to
      # the sub-command, e.g. `parrot post --title "..."`, are left untouched.
    end
  end
end
