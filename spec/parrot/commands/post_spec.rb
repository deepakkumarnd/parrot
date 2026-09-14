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
      expect(body).to include("<!--\ntitle: My First Post!\ndate: #{Date.today.strftime('%d/%m/%Y')}\nlang: en\n-->")
      expect(body).to include('# My First Post!')
      expect(body).to include('{post_date}')
    end

    it 'also accepts the title as a plain quoted argument' do
      Parrot::Commands::PostCommand.new(['A plain title'], config).run
      expect(File.exist?('blog/views/posts/a-plain-title.md')).to be true
    end

    it 'refuses to overwrite an existing post' do
      Parrot::Commands::PostCommand.new(%w( --title Dup ), config).run
      expect { Parrot::Commands::PostCommand.new(%w( --title Dup ), config).run }.to raise_error(/already exists/)
    end
  end
end
