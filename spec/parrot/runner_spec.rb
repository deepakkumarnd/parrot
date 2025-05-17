require 'spec_helper'

describe Parrot::Runner do
  let(:config)  { Parrot::Config.new(Dir.pwd, Logger.new(STDOUT)) }

  context 'Runner class' do
    it 'should raise error if no application name provided for the new sub command' do
      expect { Parrot::Runner.new('new', [], config) }.to raise_error(ArgumentError)
    end

    it 'should create a NewCommand object' do
      runner = Parrot::Runner.new('new', %w( foo ), config)
      expect(runner.command).to be_an_instance_of(Parrot::Commands::NewCommand)
    end

    it 'should create a BuildCommand object' do
      expect(Parrot::Runner.new('build', %w( foo ), config).command).to be_an_instance_of(Parrot::Commands::BuildCommand)
    end

    it 'should create a ServeCommand object' do
      expect(Parrot::Runner.new('serve', %w( foo ), config).command).to be_an_instance_of(Parrot::Commands::ServeCommand)
    end

    it 'should raise error if the command is invalid' do
      expect { Parrot::Runner.new('foo', config) }.to raise_error(NameError)
    end
  end
end