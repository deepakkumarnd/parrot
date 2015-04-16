require 'logger'

class ParrotLogger < Logger

  attr_reader :logger, :device

  def initialize(quiet = false)
    @device = quiet ? File.new('parrot.log', 'a+') : STDOUT
    @logger = Logger.new(@device)
  end

  def log(message)
    @logger.info(message)
  end
end