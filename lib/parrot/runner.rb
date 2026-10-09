require 'fileutils'
require_relative 'commands/new'
require_relative 'commands/build'
require_relative 'commands/serve'
require_relative 'commands/post'
require_relative 'commands/list'

module Parrot
  class Runner
    include Commands

    attr_reader :command

    def initialize(command, args = [], config)
      @config = config
      klass = to_command_class(command)
      @command = klass.new(args, @config)
    end

    def run_command
      @command.run
    end

    private

    # "build" -> BuildCommand, "list-tags" -> ListTagsCommand
    def to_command_class(command)
      Commands.const_get("#{command.split('-').map(&:capitalize).join}Command")
    end
  end
end
