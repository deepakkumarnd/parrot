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

  context 'ServeCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::ServeCommand.new([], config)).to respond_to(:run)
    end

    it 'run a webserver at port 8000 serving files' do
      # Parrot::Commands::ServeCommand.new([]).run
    end
  end
end