require 'spec_helper'

describe Parrot::ParrotLogger do

  let(:parrot_logger) { Parrot::ParrotLogger.new(false) }

  it 'is an instance of Logger' do
    parrot_logger.logger.class.should == Logger
  end

  it 'has a log method' do
    parrot_logger.should respond_to(:log)
  end

  it 'logs a message to stdout by default' do
    expect(parrot_logger).to receive(:log).with("Hello parrot")
    parrot_logger.log("Hello parrot")
  end

  it 'sets the instance variable @logger' do
    parrot_logger.instance_variable_defined?(:@logger).should be true
  end

  it 'sets the instance variable @device' do
    parrot_logger.instance_variable_defined?(:@device).should be true
  end

  it 'sets the log device as STDOUT by default' do
    parrot_logger.device.should == STDOUT
  end

  it 'sets the log device as a file if the quiet mode is turned on' do
    Parrot::ParrotLogger.new(quiet = true).device.class.should == File
  end
end