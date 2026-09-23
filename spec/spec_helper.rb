require 'pry'
require_relative '../lib/parrot'

ENV['PARROT_TESTING'] = "true"

TestLogger = Parrot::ParrotLoggerBuilder.new(false).logger