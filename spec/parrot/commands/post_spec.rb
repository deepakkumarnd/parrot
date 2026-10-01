require 'spec_helper'

describe Parrot::Commands do
  let(:config) { Parrot::Config.new(File.expand_path('blog'), TestLogger) }

  before do
    FileUtils.rm_rf('blog')
    Parrot::Commands::NewCommand.new(%w[blog], config).run
  end

  after do
    FileUtils.rm_rf('blog')
  end

  context 'PostCommand' do
    it 'has a run method' do
      expect(Parrot::Commands::PostCommand.new(%w[--title hello], config)).to respond_to(:run)
    end

    it 'shows the usage example when called without a title' do
      expect { Parrot::Commands::PostCommand.new([], config) }
        .to raise_error(ArgumentError, /parrot post --title "My new post"/)
    end

    it 'shows the usage example when --title is given no value' do
      expect { Parrot::Commands::PostCommand.new(%w[--title], config) }
        .to raise_error(ArgumentError, /parrot post --title "My new post"/)
    end

    it 'shows the usage example when the title has no usable characters' do
      expect { Parrot::Commands::PostCommand.new(%w[--title !!!], config).run }
        .to raise_error(ArgumentError, /parrot post --title "My new post"/)
    end

    it 'accepts the title from --title, including trailing words' do
      Parrot::Commands::PostCommand.new(['--title', 'My', 'First', 'Post!'], config).run

      post_path = 'blog/views/posts/my-first-post.md'
      expect(File.exist?(post_path)).to be true

      body = File.read(post_path)
      expect(body).to include("<!--\ntitle: My First Post!\ndate: #{Date.today.strftime('%d/%m/%Y')}\nlang: en\ncategory:\n-->")
      expect(body).to include('# {post_title}')
      # the build adds the date under the title itself now
      expect(body).not_to include('{post_date}')
    end

    it 'also accepts the title as a plain quoted argument' do
      Parrot::Commands::PostCommand.new(['A plain title'], config).run
      expect(File.exist?('blog/views/posts/a-plain-title.md')).to be true
    end

    %w[About 404 Index index2 ABOUT Now post Posts note NOTES Category Categories].each do |title|
      it "refuses the reserved title #{title.inspect}" do
        expect { Parrot::Commands::PostCommand.new(['--title', title], config).run }
          .to raise_error(ArgumentError, /is a reserved post name/)
        expect(Dir['blog/views/posts/*.md'].map { |path| File.basename(path) })
          .to contain_exactly('about_parrot.md', 'sample.md')
      end
    end

    it 'allows titles that only contain a reserved word' do
      Parrot::Commands::PostCommand.new(['--title', 'About me'], config).run
      Parrot::Commands::PostCommand.new(['--title', 'Index 2'], config).run
      Parrot::Commands::PostCommand.new(['--title', 'Notes on Ruby'], config).run
      Parrot::Commands::PostCommand.new(['--title', 'Nowhere'], config).run
      Parrot::Commands::PostCommand.new(['--title', 'Category theory'], config).run
      expect(File.exist?('blog/views/posts/about-me.md')).to be true
      expect(File.exist?('blog/views/posts/index-2.md')).to be true
      expect(File.exist?('blog/views/posts/notes-on-ruby.md')).to be true
      expect(File.exist?('blog/views/posts/nowhere.md')).to be true
      expect(File.exist?('blog/views/posts/category-theory.md')).to be true
    end

    it 'refuses to overwrite an existing post' do
      Parrot::Commands::PostCommand.new(%w[--title Dup], config).run
      expect { Parrot::Commands::PostCommand.new(%w[--title Dup], config).run }.to raise_error(/already exists/)
    end
  end
end
