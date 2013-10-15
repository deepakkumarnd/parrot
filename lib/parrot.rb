require 'optparse'

require 'parrot/version'
require 'parrot/builder'
require 'parrot/logger'

module Parrot
  require 'parrot/builder'

  class Parrot
    SUB_COMMANDS = %w( new build watch )

    def initialize(args = [])
      @options = { quiet: false }

      OptionParser.new do |opts|
        opts.on('-q', '--quiet', 'Quiet mode') { @options[:quiet] = true }
        opts.on_tail('-v', '--version', 'Prints version information') { puts "Parrot #{VERSION}" and exit }
        opts.on_tail('-h', '--help', 'HELP TEXT') { puts 'Help message' and exit }
      end.parse!(args)

      command = args.shift
      Parrot.usage and exit unless SUB_COMMANDS.include?(command)
      Builder.new(command)
    end

    def self.usage
      puts 'parrot <subcommand> options'
    end

    def quiet?
      @options[:quiet]
    end
  end
end

Parrot::Parrot.new(ARGV)