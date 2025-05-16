require 'logger'

module Parrot
  class ParrotLogger

    attr_reader :logger, :device

    def initialize(quiet = false)
      @device = quiet ? File.new('parrot.log', 'a+') : STDOUT
      # shift_age = 10, keep 10 log files
      # shift_size = 1048576, maximum 1 MB of log file size
      @logger = Logger.new(@device, shift_age=10, shift_size=1048576, progname: self.class.name)
    end

    def log(message)
      @logger.info(message)
    end
  end
end