require 'spec_helper'

describe Parrot::Runner do

  context 'Runner class' do
    fit 'should raise error if no application name provided for the new sub command' do
      expect { Parrot::Runner.new('new') }.to raise_error(ArgumentError)
    end

    it 'should choose the class NewCommand as the command class for the new subcommand' do
      runner = Parrot::Runner.new('new', %w( foo ))
      expect(runner.command).to be_an_instance_of(Parrot::Commands::NewCommand)
    end

    it 'should create a BuildCommand object' do
      Parrot::Runner.new('build')
    end

    it 'should create a NewCommand object' do
      # Parrot::Builder.new('watch')
    end

    it 'should raise error if the command is invalid' do
      expect { Parrot::Runner.new('foo') }.to raise_error(NameError)
    end
  end
end

describe Parrot::Commands do
  context 'NewCommand' do
    it 'has a run method' do
      Parrot::Commands::NewCommand.new(%w( foo )).should respond_to(:run)
    end

    fit 'creates a blog application' do
      Parrot::Commands::NewCommand.new(%w( blog )).run
      expect(Dir.exist?('blog')).to be true

      file_list = %w[blog/css/app.scss blog/javascripts/app.js blog/images/favicon.ico blog/images/favicon-16x16.png blog/images/favicon-32x32.png blog/images/favicon-96x96.png blog/views/layout.html.erb blog/views/index.md blog/views/posts/post1.md blog/views/posts/post2.md blog/public/.keep]

      expect(file_list.all? { |file| File.exist?(file) }).to be true
      # cleanup
      FileUtils.rm_rf('blog')
    end
  end
end