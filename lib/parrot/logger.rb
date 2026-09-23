require 'logger'

module Parrot
  class ParrotLoggerBuilder
  
    attr_reader :logger, :device

    def initialize(quiet = false)
      @device = if Helpers.testing?
        File.new('parrot.test.log', 'a+') 
      else
        quiet ? File.new('parrot.log', 'a+') : STDOUT
      end
      
      # shift_age = 10, keep 10 log files
      # shift_size = 1048576, maximum 1 MB of log file size
      @logger = Logger.new(@device, shift_age=10, shift_size=1048576, progname: 'ParrotLogger')
    end

    def log(message)
      @logger.info(message)
    end
  end
end