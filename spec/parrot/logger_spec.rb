require 'spec_helper'

describe Parrot::ParrotLoggerBuilder do

  let(:parrot_logger) { Parrot::ParrotLoggerBuilder.new(false) }

  it 'is an instance of Logger' do
    expect(parrot_logger.logger).to be_an_instance_of(Logger)
  end

  it 'has a log method' do
    expect(parrot_logger).to respond_to(:log)
  end

  it 'logs a message to stdout by default' do
    expect(parrot_logger).to receive(:log).with("Hello parrot")
    parrot_logger.log("Hello parrot")
  end

  it 'sets the instance variable @logger' do
    expect(parrot_logger.instance_variable_defined?(:@logger)).to be true
  end

  it 'sets the instance variable @device' do
    expect(parrot_logger.instance_variable_defined?(:@device)).to be true
  end

  it 'sets the log device as STDOUT by default' do
    expect(parrot_logger.device).to eq(STDOUT)
  end

  it 'sets the log device as a file if the quiet mode is turned on' do
    expect(Parrot::ParrotLoggerBuilder.new(quiet = true).device).to be_a File
  end
end