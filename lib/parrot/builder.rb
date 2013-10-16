module Parrot

  module Commands
    class NewCommand
      def execute
        puts 'creating new application'
      end
    end

    class BuildCommand
      def execute
        puts 'building application'
      end
    end

    class WatchCommand
      def execute
        puts 'watching application'
      end
    end
  end

  class Builder

    include Commands

    def initialize(command)
      klass = to_command_class(command)
      #klass.new
    end

    private

    def to_command_class(command)
      Commands.const_get("#{command.capitalize}Command")
    end
  end
end