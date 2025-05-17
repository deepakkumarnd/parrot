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

describe Parrot::Commands do
  let(:config)  { Parrot::Config.new(Dir.pwd, Logger.new(STDOUT)) }

  context 'NewCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::NewCommand.new(%w( foo ), config)).to respond_to(:run)
    end

    it 'creates a blog application' do
      Parrot::Commands::NewCommand.new(%w( blog ), config).run
      expect(Dir.exist?('blog')).to be true

      file_list = %w[blog/css/app.scss blog/javascripts/app.js blog/images/favicon.ico blog/images/favicon-16x16.png blog/images/favicon-32x32.png blog/images/favicon-96x96.png blog/views/layout.html.erb blog/views/index.md blog/views/posts/post1.md blog/views/posts/post2.md blog/public/.keep]

      expect(file_list.all? { |file| File.exist?(file) }).to be true
      # cleanup
      FileUtils.rm_rf('blog')
    end
  end
end


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
    fit 'has a run method' do
      expect(Parrot::Commands::ServeCommand.new([], config)).to respond_to(:run)
    end

    fit 'run a webserver at port 8000 serving files' do
      # Parrot::Commands::ServeCommand.new([]).run
    end
  end
end