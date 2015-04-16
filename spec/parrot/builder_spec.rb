require 'spec_helper'

describe Parrot::Builder do

  context 'Builder Class' do
    it 'should raise error if no application name provided' do
      expect { Parrot::Builder.new('new') }.to raise_error(ArgumentError)
    end

    it 'should choose the class NewCommand as the command class' do
      Parrot::Commands::NewCommand.any_instance.should_receive(:run).and_return(nil)
      builder = Parrot::Builder.new('new', %w( foo ))
      builder.klass.should == Parrot::Commands::NewCommand
    end

    it 'should create a BuildCommand object' do
      Parrot::Builder.new('build')
    end

    it 'should create a NewCommand object' do
      # Parrot::Builder.new('watch')
    end

    it 'should raise error if the command is invalid' do
      expect { Parrot::Builder.new('foo') }.to raise_error(NameError)
    end
  end
end

describe Parrot::Commands do
  context 'NewCommand' do
    it 'has a run method' do
      Parrot::Commands::NewCommand.new(%w( foo )).should respond_to(:run)
    end

    it 'creates a foo application' do
      Parrot::Commands::NewCommand.new(%w( foo )).run
      Dir.exists?('foo').should be_true
      FileUtils.rm_rf('foo')
    end
  end
end