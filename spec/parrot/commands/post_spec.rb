require 'spec_helper'

describe Parrot::Commands do
  let(:config) { Parrot::Config.new(File.expand_path('blog'), Logger.new(STDOUT)) }

  before do
    FileUtils.rm_rf('blog')
    Parrot::Commands::NewCommand.new(%w( blog ), Parrot::Config.new(Dir.pwd, Logger.new(STDOUT))).run
  end

  after do
    FileUtils.rm_rf('blog')
  end

  context 'PostCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::PostCommand.new(%w( --title hello ), config)).to respond_to(:run)
    end

    it 'shows the usage example when called without a title' do
      expect { Parrot::Commands::PostCommand.new([], config) }
        .to raise_error(ArgumentError, /parrot post --title "My new post"/)
    end

    it 'shows the usage example when --title is given no value' do
      expect { Parrot::Commands::PostCommand.new(%w( --title ), config) }
        .to raise_error(ArgumentError, /parrot post --title "My new post"/)
    end

    it 'shows the usage example when the title has no usable characters' do
      expect { Parrot::Commands::PostCommand.new(%w( --title !!! ), config).run }
        .to raise_error(ArgumentError, /parrot post --title "My new post"/)
    end

    it 'accepts the title from --title, including trailing words' do
      Parrot::Commands::PostCommand.new(['--title', 'My', 'First', 'Post!'], config).run

      post_path = 'blog/views/posts/my-first-post.md'
      expect(File.exist?(post_path)).to be true

      body = File.read(post_path)
      expect(body).to include('# My First Post!')
      expect(body).to include(Date.today.to_s)

      index = File.read('blog/views/index.md')
      expect(index).to include("- [My First Post!](#my-first-post.md) — #{Date.today}")

      # newest post sits above the ones that were already listed
      list = index.lines.select { |line| line.lstrip.start_with?('- ') }
      expect(list.first).to include('my-first-post.md')
    end

    it 'also accepts the title as a plain quoted argument' do
      Parrot::Commands::PostCommand.new(['A plain title'], config).run
      expect(File.exist?('blog/views/posts/a-plain-title.md')).to be true
    end

    it 'prepends each new post so the newest is first' do
      Parrot::Commands::PostCommand.new(%w( --title First ), config).run
      Parrot::Commands::PostCommand.new(%w( --title Second ), config).run

      list = File.read('blog/views/index.md').lines.select { |line| line.lstrip.start_with?('- ') }
      expect(list[0]).to include('second.md')
      expect(list[1]).to include('first.md')
    end

    it 'refuses to overwrite an existing post' do
      Parrot::Commands::PostCommand.new(%w( --title Dup ), config).run
      expect { Parrot::Commands::PostCommand.new(%w( --title Dup ), config).run }.to raise_error(/already exists/)
    end
  end
end
