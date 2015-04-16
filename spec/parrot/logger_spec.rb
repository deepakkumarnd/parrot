require 'spec_helper'

describe ParrotLogger do

  let(:parrot_logger) { ParrotLogger.new(false) }

  it 'has a logger attribute' do
    parrot_logger.logger.class.should == Logger
  end

  it 'has a log method' do
    parrot_logger.should respond_to(:log)
  end

  it 'sets the instance variable @logger' do
    parrot_logger.instance_variable_defined?(:@logger).should be_true
  end

  it 'sets the instance variable @device' do
    parrot_logger.instance_variable_defined?(:@device).should be_true
  end

  it 'sets the log device as STDOUT by default' do
    parrot_logger.device.should == STDOUT
  end

  it 'sets the log device as a file if the quiet mode is turned on' do
    ParrotLogger.new(quiet = true).device.class.should == File
  end
end