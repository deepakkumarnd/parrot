require 'fileutils'
require_relative 'commands/new'
require_relative 'commands/build'
require_relative 'commands/serve'

class HTMLWithPygments < Redcarpet::Render::HTML
  # def block_code(code, language)
  #   Pygments.highlight(code, :formatter => 'terminal')
  # end
end

module Parrot

  class Runner

    include Commands

    attr_reader :command

    def initialize(command, args=[], config)
      @config = config
      klass = to_command_class(command)
      @command = klass.new(args, @config)
    end

    def run_command
      @command.run
    end

    private

    def to_command_class(command)
      Commands.const_get("#{command.capitalize}Command")
    end
  end
end
