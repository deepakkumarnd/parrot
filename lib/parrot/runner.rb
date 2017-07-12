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
