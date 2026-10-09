require 'spec_helper'

describe Parrot::Commands do
  let(:config) { Parrot::Config.new(File.expand_path('blog'), TestLogger) }

  before do
    FileUtils.rm_rf('blog')
    Parrot::Commands::NewCommand.new(%w[blog], config).run
    FileUtils.rm_f(Dir['blog/views/posts/*.md'])
  end

  after do
    FileUtils.rm_rf('blog')
  end

  def write_post(name, header)
    File.write("blog/views/posts/#{name}.md", "<!--\n#{header}\n-->\n\n# Post\n")
  end

  context 'ListTagsCommand' do
    it 'lists every tag with its post count, sorted by name' do
      write_post('one', "title: One\ntags: ruby, coding")
      write_post('two', "title: Two\ntags: Algorithms, ruby, ruby")
      write_post('three', 'title: Three')

      expect { Parrot::Commands::ListTagsCommand.new([], config).run }
        .to output("Algorithms (1)\ncoding (1)\nruby (2)\n").to_stdout
    end

    it 'counts tags on drafts too' do
      write_post('draft', "title: Draft\ndraft: true\ntags: wip")

      expect { Parrot::Commands::ListTagsCommand.new([], config).run }.to output("wip (1)\n").to_stdout
    end

    it 'says so when no post has tags' do
      write_post('one', 'title: One')

      expect { Parrot::Commands::ListTagsCommand.new([], config).run }.to output("No tags yet.\n").to_stdout
    end
  end

  context 'ListCategoriesCommand' do
    it 'lists every category with its post count, sorted by name' do
      write_post('one', "title: One\ncategory: Programming")
      write_post('two', "title: Two\ncategory: Life")
      write_post('three', "title: Three\ncategory: Programming")
      write_post('four', "title: Four\ncategory:")

      expect { Parrot::Commands::ListCategoriesCommand.new([], config).run }
        .to output("Life (1)\nProgramming (2)\n").to_stdout
    end

    it 'says so when no post has a category' do
      write_post('one', 'title: One')

      expect { Parrot::Commands::ListCategoriesCommand.new([], config).run }
        .to output("No categories yet.\n").to_stdout
    end

    it 'fails outside a blog root' do
      outside = Parrot::Config.new(File.expand_path('blog/views'), TestLogger)

      expect { Parrot::Commands::ListCategoriesCommand.new([], outside).run }
        .to raise_error(/Run this from the blog's root/)
    end
  end
end
