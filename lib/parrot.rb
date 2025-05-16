$LOAD_PATH<< File.dirname(__FILE__)

require 'optparse'

require 'parrot/version'
require 'parrot/runner'
require 'parrot/logger'

module Parrot
  class Parrot
    SUB_COMMANDS = %w( new build serve )
    Root = Dir.pwd

    def initialize(args = [])
      @options = { quiet: false }
      extract_options!(args)
      command = args.shift
      exit_if_invalid(command)
      @logger = ParrotLogger.new(@options[:quiet])
      Runner.new(command, args).run_command
    end

    def log(message)
      @logger.log(message)
    end

    def self.usage
      puts "Usage: parrot #{SUB_COMMANDS.join('|')} options"
    end

    def exit_if_invalid(command)
      if command.nil? || !SUB_COMMANDS.include?(command)
        Parrot.usage
        exit!
      end
    end

    def quiet?
      @options[:quiet]
    end

    def self.root
      Parrot::Root
    end

    private

    def extract_options!(args)
      OptionParser.new do |opts|
        opts.on('-q', '--quiet', 'Quiet mode') { @options[:quiet] = true }
        opts.on_tail('-v', '--version', 'Prints version information') { puts("Parrot #{VERSION}") }
        opts.on_tail('-h', '--help', 'HELP TEXT') do
          puts 'Help message'
        end
      end.parse!(args)
    end
  end
end