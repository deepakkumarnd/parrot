require 'spec_helper'

describe Parrot::Commands do
  let(:config)  { Parrot::Config.new(Dir.pwd, Logger.new(STDOUT)) }

  before do
    # create a new application
    Parrot::Commands::NewCommand.new(%w( blog ), config).run
  end

  after do
    # cleanup
    FileUtils.rm_rf('blog')
  end

  context 'BuildCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::BuildCommand.new([], config)).to respond_to(:run)
    end
  end
end